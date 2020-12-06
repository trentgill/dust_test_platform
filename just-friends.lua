--- Just Friends Test


-- global constants
--VERBOSE       = true -- prints every test report
--FIRMWARE      = "~/dev/Just-Friends/JF_v4_0_0.bin" -- TODO use a combo flash
FIRMWARE      = "~/dev/JFcombo.bin"
FLASH_ADDRESS = 0x08000000

--- list of DUT sources & the settings required for mux selection
-- { test_amps, test_source }
ctest_sources =
    { ['+12A'] = {1, 0}
    , ['-12A'] = {2, 0}
    , ['+12V'] = {0, 1}
    , ['-12V'] = {0, 2}
    , ['+3V3'] = {0, 3}
    , ['+3V1'] = {0, 4}
    , vref_in  = {0, 5}
    , vref_out = {0, 6}
    , ['-5V']  = {0, 7}
    , jack     = {0, 8}
    , none     = {0, 0}
    }

ctest_dests =
    { v8      = 1
    , trigger = 2
    , jack    = 3
    , none    = 0
    }
    

---------------------------
-- private global vars

function globals()
    clk_id = {}
    errors = {} -- TODO fill with table of strings to display to tester, one per error
    rxd = 0
    expectation = 0
    window = 0
    UID = {}
    timeout = {} -- clock routine for timeout
    ok_disabled = false
    
    screens =
        { start     = draw_start
        , flash     = draw_flash
        , intensity = draw_intensity
        , pots      = draw_pots
        , switches  = draw_switches
        , cvs       = draw_cvs
        , trs       = draw_trs
        , outs      = draw_outs
        , report    = draw_report
        }
    current_screen = screens.start
    
    -- guided elements
    screenstate = {"bright",15}
    guide_status = ""
end


---------------------------------------------------------
--- main program

function init()
    ctest_reset() -- reset crow environment. TODO more extreme?
    
    clk_id = clock.run(begin_test) -- TODO this should be managed by the norns UI
    -- clk_id = clock.run(begin_test, true) -- forces re-uploading of the firmware
end

function ctest_reset()
    crow.output[1].volts = 0
    crow.output[1].slew = 0
    
    crow.send "test_amps(0)"
    crow.send "test_source(0)"
    crow.send "test_dest(0)"
    
    -- accept CV values by reassigning event callback
    function async_resume(v)
        rxd = v               -- save reading
        clock.cancel(timeout) -- stop timeout counter
        clock.resume(clk_id)  -- jump back to test
    end
        
    crow.input[1].stream = function( v ) async_resume(v) end
    crow.ii.jf.event = function( e, v ) async_resume(v) end

    log_clear()    
    set_screen('start')
end

function key(n,s)
    if guide_status ~= "" then
        if n == 2 and s == 1 then
            log_error{ guide_status, "FAIL", "" }
            guide_status = ""
            async_resume(0)
        elseif n == 3 and s == 1 and not ok_disabled then
            guide_status = ""
            async_resume(0)
        end
    end
end


-----------------------------------------------------------------------------
--- test cases { ctest_sources, expectation, window }

-- FIXME need to fine-tune these values after calibrating the testplatform

-- 'critical' will be run individually & will power-down immediately if any test fails
current_draw =
    { { "+12A", 1.21, 0.2 }
    , { "-12A", 0.78, 0.2 }
    }

operating_points =                     -- VMeter
    { { "+12V"    ,  3.75, 0.3 } --  11.59 => 3v77 (/3)
    , { "-12V"    , -3.59, 0.3 } -- -11.86 => -3v6 (/3)
    , { "+3V3"    ,  3.27, 0.2 } --
    , { "+3V1"    ,  3.10, 0.2 } --  3.10
    , { "vref_in" , -1.39, 0.2 } -- -1.50
    , { "vref_out",  1.34, 0.2 } --  1.30
    , { "-5V"     , -4.80, 0.3 } -- -4.99
    }


function begin_test( force_flash )
    --ctest_power(true)
    
    -- FIXME ctest_suite( current_draw ) erroneously succeeding when no value is returned (due to no firmware)
    if ctest_suite( current_draw ) ~= 'fail' then -- FIXME change to ctest_critical()

        ctest_suite( operating_points )
        --VERBOSE = true
        local flash_ok = 1
        if force_flash or not ctest_has_flash() then
            _, _, flash_ok = ctest_flash( FIRMWARE, FLASH_ADDRESS )
        end
        if flash_ok == 1 then
            ctest_ii_query()
            ctest_guide()
        else
            print "FLASH failed. FIXME retry?"
        end
    --[[
    ]]
    end
    
    --ctest_power(false)
    
    log_print()
    set_screen "report"
end


function ctest_ii_query()
    enter_test_mode()
    get_uid()
    test_cv_static()
    test_trigger_static() -- UNUSED as hardware shorts test point to ground
end


function ctest_guide()
    -- GUIDE
    --test_lights()
    --test_pots()
    --test_switches()
    test_jacks_cv()
    test_jacks_tr()
    test_jacks_outs()
end


function suspend_with_timeout(s)
    timeout = clock.run( function() clock.sleep(s); async_resume() end, s )
    clock.suspend()
end



function ctest_flash( bin, addr )
    return os.execute( string.format("st-flash --reset write %s 0x%x", bin, addr) )
end


-- ii.jf.test(n) where n is:
iiset =
    { reset     = 0
    , start     = 1
    , save      = 2
    , lights    = {3,4,5}
    , zerovolts = 10
    , twovolts  = 12
    }

-- ii.jf.get('test',n) where n is:
iiget =
    { uid     = { 1,2,3,4,5,6 }
    , pRamp   = 7
    , pIntone = 8
    , pFM     = 9
    , pTime   = 10
    , pCurve  = 11
    , cRun    = 12
    , cRamp   = 13
    , cFM     = 14
    , cIntone = 15
    , cTime   = 16
    , cCurve  = 17
    , sRun    = 18
    , sTrigger= 19
    , swSpeed = 20
    , swTSC   = 21
    }

ii_cv_tests =
    { { "cRun"   , 32767, 2500 } -- FIXME broken due to jack-detection
    , { "cRamp"  , 32767, 500 }
    , { "cFM"    , 32767, 500 }
    , { "cIntone", 32767, 2500 }
    , { "cTime"  , 42697, 5000 } -- 65535 * 0.651515
    , { "cCurve" , 32767, 500 }
    }

    

function ctest_iiset( n, ix )
    if ix then
        crow.send( "ii.jf.test(".. iiset[n][ix] ..")" )
    else
        crow.send( "ii.jf.test(".. iiset[n] ..")" )
    end
end

function ctest_iiget(n)
    crow.send( "ii.jf.get('test',"..n..")" )
end

function ctest_has_flash()
    clock.sleep(0.01)           -- ensure jf has booted
    rxd = false                 -- mark for timeout
    ctest_iiget( iiget.uid[1] ) -- attempt to read the UID
    suspend_with_timeout(0.1)
    if rxd then return true
    else return false end
end



--- building blocks

function enter_test_mode()
    clock.sleep(0.01) -- ensure jf has (re)booted
    ctest_iiset( "start" )
end

function get_uid()
    -- store UID for tracking serial numbers
    local uids = {}
    for i=1,6 do
        rxd = false
        ctest_iiget( iiget.uid[i] )
        suspend_with_timeout(0.1)
        if rxd then uids[i] = rxd -- save value
        else print "TODO handle UID not returning a value" end
    end
    UID = string.format("0x%04x%04x%04x%04x%04x%04x",uids[1],uids[2],uids[3],uids[4],uids[5],uids[6])
end

function test_cv_static()
    -- test CV states
    clock.sleep(0.01) -- wait for voltages to settle
    for k,v in ipairs(ii_cv_tests) do
        rxd = false
        ctest_iiget( iiget[v[1]] )
        suspend_with_timeout(0.1)
        if rxd then check_expectation( v[1], v[2], v[3] )
        else print "TODO handle static cv over i2c not returning a value" end
    end
end


-- UNUSED as the hardware shorts the test point to ground.
function test_trigger_static()
    -- test trigger jacks with TR_IN pin
    set_dest "trigger"
    
    -- Trigger LOW
    crow.output[1].volts = 0
    rxd = false
    ctest_iiget( iiget.sTrigger )
    suspend_with_timeout(0.1)
    if rxd then check_expectation( 'Tr_L', 0, 0.1 )
    else print "TODO handle tr_L over i2c not returning a value" end
    
    -- Trigger HIGH
    crow.output[1].volts = 10
    clock.sleep(0.1)
    rxd = false
    ctest_iiget( iiget.sTrigger )
    suspend_with_timeout(0.1)
    if rxd then check_expectation( 'Tr_H', 6, 0.1 )
    else print "TODO handle tr_H over i2c not returning a value" end
    
    --clock.sleep(60)
    
    set_dest "none"
end

-----------------------------------------------------
--- guided hw tests

function test_lights()
    set_screen "intensity"
    
    local function test_light_stage(stat,name,level,cmd)
        guide_status = stat
        screenstate = { name, level }
        crow.send( "ii.jf.test(".. iiset.lights[cmd] ..")" )
        redraw()
        suspend_with_timeout(10)
    end
    
    test_light_stage("lights_bright","bright",15,3)
    test_light_stage("lights_dim","dim",7,2)
    test_light_stage("lights_off","off",2,1)
end

function test_pots()
    local MUL   = (5/3)*math.pi
    local SHIFT = 2*math.pi/3
    
    crow.ii.jf.event = function( e, v )
        if rxd ~= 0 then
            screenstate[rxd] = MUL * (v / 4095) + SHIFT
            rxd = 0
            redraw()
        end
    end
    
    -- start streaming pot values from DUT
    local query = clock.run(function()
        local chan = 7
        while true do
            chan = chan + 1
            if chan > 11 then chan = 7 end
            if rxd ~= 0 then print "overrun" end
            rxd = chan-6 -- shift to 1-based
            ctest_iiget( chan )
            clock.sleep(0.02)
            
        end
    end)

    screenstate = {0,0,0,0,0,"min"}
    set_screen "pots"
    
    guide_status = "pots_minimum"
    screenstate[6] = "min"
    redraw()
    suspend_with_timeout(60)

    guide_status = "pots_12:00"
    screenstate[6] = "12:00"
    redraw()
    suspend_with_timeout(60)
    
    guide_status = "pots_maximum"
    screenstate[6] = "max"
    redraw()
    suspend_with_timeout(60)
    
    clock.cancel(query) -- stop streaming pot values
end

function test_switches()
  
    -- capture response
    crow.ii.jf.event = function( e, v )
        if rxd ~= 0 then
            screenstate[rxd] = v -- save current state
            if rxd == 1 then
                screenstate[3][v+1] = 1 -- store value as activated
            else
                screenstate[4][v] = 1 -- touched
            end
            rxd = 0
            redraw()
        end
    end
    
    -- start streaming switch values from DUT
    local query = clock.run(function()
        local chan = 'speed'
        while true do
            if chan == 'speed' then chan = 'tsc' else chan = 'speed' end -- flip state
            if rxd ~= 0 then print "overrun" end
            rxd = (chan == 'speed') and 1 or 2 -- speed = 1, tsc = 2
            ctest_iiget( (chan == 'speed') and iiget.swSpeed or iiget.swTSC )
            clock.sleep(0.02)
        end
    end)
    
    screenstate = {0, 0, {0,0}, {0,0,0} } -- current states, captured states
    set_screen "switches"
    
    guide_status = "move_switches"
    redraw()
    suspend_with_timeout(60)
    
    clock.cancel(query) -- stop streaming switch values
end

function test_jacks_cv()

end

function test_jacks_tr()
    -- test trigger jacks with patch cable
    set_dest "jack"
    
    crow.ii.jf.event = function( e, v )
        if rxd ~= 0 then
            screenstate[rxd] = v -- save current state
            if rxd == 1 then
                screenstate[3][v+1] = 1 -- store value as activated
            else
                screenstate[4][v] = 1 -- touched
            end
            rxd = 0
            redraw()
        end
    end
    
    --[[
    -- Trigger LOW
    crow.output[1].volts = 3
    clock.sleep(60)
    rxd = false
    ctest_iiget( iiget.sTrigger )
    suspend_with_timeout(0.1)
    if rxd then check_expectation( 'Tr_L', 0, 0.1 )
    else print "TODO handle tr_L over i2c not returning a value" end
    
    -- Trigger HIGH
    crow.output[1].volts = 10
    clock.sleep(0.1)
    rxd = false
    ctest_iiget( iiget.sTrigger )
    suspend_with_timeout(0.1)
    if rxd then check_expectation( 'Tr_H', 6, 0.1 )
    else print "TODO handle tr_H over i2c not returning a value" end
    
    --clock.sleep(60)
    
    ]]

    screenstate = {0} -- reset
    set_screen "trs"
    
    guide_status = "jacks_tr"
    redraw()
    suspend_with_timeout(60)
    
    clock.cancel(query) -- stop streaming
    
    set_dest "none" -- deactivate output jack
end

function test_jacks_outs()

end






---------------------------------------------------------------------
--- high-level test wrappers

function ctest_power(bool)
    -- TODO causes system to reset when flipping state
    -- i am guessing it has to do with power draw causing a regulator to drop out or voltage to droop somewhere
    -- so waiting on a USB power meter to test.
    -- in the meantime, just let the power be always on as we know there's no power short on the test board.
    --crow.send("test_power("..(bool and 1 or 0)..")")
    --print("POWER "..tostring(bool))
end


function ctest_suite( cases )
    for k,v in ipairs( cases ) do
        run_cv_test( v )
    end
end


-- critical test, will return early on any failed test
function ctest_critical( cases )
    for k,v in ipairs( cases ) do
        local errstate = run_cv_test( v )
        if errstate then return errstate end
    end
end


------------------------------------------------------------------------
--- low-level helper functions

function set_source( name )
    local srcs = ctest_sources[name]
    if srcs[1] == 0 then -- change amps first
        crow.send "test_amps(0)"
        clock.sleep(0.005) -- ensure bbm
        crow.send( "test_source("..srcs[2]..")" )
    else -- change srcs
        crow.send "test_source(0)"
        clock.sleep(0.005) -- ensure bbm
        crow.send( "test_amps("..srcs[1]..")" )
    end
    clock.sleep(0.005) -- wait for reading to settle
end


function set_dest( name )
    crow.send( "test_dest("..(ctest_dests[name] or 0)..")" )
    clock.sleep(0.005) -- wait for output to settle (redundant with input sleep?)
end


function run_cv_test( case )
    set_source( case[1] )
    rxd = false -- unset truthiness so we can ensure we've read a value
    expectation = case[2]
    window = case[3]
    crow.input[1].query() -- request the value from crow
    suspend_with_timeout(0.1)

    -- clock.resume triggered by response to input[1].query()
    if rxd then -- TODO this will catch a timeout, rather than a response
        check_expectation( case[1], expectation, window )
    else
        print "Timeout: value was not returned from crow"
    end
    
    return 'fail'
end


function check_expectation( name, expectation, window )
    local minw = expectation-window
    local maxw = expectation+window
    if rxd > minw and rxd < maxw then -- in range
        if VERBOSE then
            print("OK! at test: "..name) -- print test name
            print("  expected: ("..minw.." .. "..maxw..")")
            print("  received: "..rxd)
        end
        return
    else -- out of range
        if VERBOSE then
            print("FAIL! at test: "..name) -- print test name
            print("  expected: ("..minw.." .. "..maxw..")")
            print("  received: "..rxd)
        end
        --log_error( name.. ": expected ("..minw.." .. "..maxw.."). received: "..rxd)

        log_error{ name, expectation, rxd }
    end
end


---------------------------------------------------------
--- logging
-- currently only supports strings, but could be extended to include readouts of expectation & returned vals

function log_clear()
    errors = {}
end

function log_error(s)
    table.insert(errors, s)
end

function log_report()
    local s = {}
    local count = #errors
    if count > 0 then
        s[1] = count .. " TESTS FAILED!"
        s[2] = "name   expect   got"
        for k,v in ipairs(errors) do
            s[k+2] = v[1] .. ":   " .. v[2] .. ",    " .. v[3]
        end
    else
        s[1] = "ALL TESTS PASSED :)"
    end
    return s
end

function log_print()
    local count = #errors
    if count > 0 then
       print(count .. " TESTS FAILED!")
        for k,v in ipairs(errors) do
            print(v[1] .. ":   " .. v[2] .. ",    " .. v[3])
        end
    else
        print("ALL TESTS PASSED :)")
    end
end


---------------------------------------------------------
--- UI

function redraw()
    screen.clear()
    screen.level(15)
    current_screen()
    screen.update()
end

function set_screen(page)
    local s = screens[page]
    if s then
        current_screen = s
        redraw()
    else print "screen doesn't exist" end
end

function draw_start()
    screen.move(0,40)
    screen.text "just friends test"
end

function draw_flash()
    screen.move(0,40)
    screen.text "flash"
end


function draw_intensity()
    screen.move(0,10)
    screen.text "lights"
    screen.move(16,32)
    screen.font_size(16)
    screen.level(screenstate[2])
    screen.text(screenstate[1])
    draw_add_okfail()
end


function draw_pots()
    screen.move(0,10)
    screen.text "pots"

    ok_disabled = false
    function pot(name,x_off,y_off,rotation,guide)
        local in_range = false
        screen.level(15)
        if guide == "min" then
            if rotation < 2.35 then in_range = true end
            -- draw the guide marker
            screen.level(15)
            screen.move(19+x_off, 40+y_off)
            screen.line(17+x_off, 42+y_off)
            screen.stroke()
        elseif guide == "12:00" then
            if rotation > 4.35 and rotation < 4.9 then in_range = true end
            -- draw the guide marker
            screen.level(15)
            screen.move(25+x_off, 18+y_off)
            screen.line(25+x_off, 20+y_off)
            screen.stroke()
        elseif guide == "max" then
            if rotation > 7.2 then in_range = true end
            -- draw the guide marker
            screen.level(15)
            screen.move(31+x_off, 40+y_off)
            screen.line(33+x_off, 42+y_off)
            screen.stroke()
        else print "unsupported guide"
        end
        -- dim the arc when it's in-range
        screen.level(in_range and 2 or 8)
        if not in_range then ok_disabled = true end -- disable the OK button if any pot is not in range
        screen.move(25+x_off,30+y_off)
        screen.arc(25+x_off,30+y_off,9,rotation,rotation-0.01)
        screen.stroke()

    end
    pot("ramp", 0, 4, screenstate[1],screenstate[6])
    pot("intone", 23, -18, screenstate[2],screenstate[6])
    pot("fm", 46, 4, screenstate[3],screenstate[6])
    pot("time", 69, -18, screenstate[4],screenstate[6])
    pot("curve", 91, 4, screenstate[5],screenstate[6])
    
    screen.level(2)
    screen.move(128, 60)
    screen.text_right( "turn pots to " .. screenstate[6] )
            
    draw_add_okfail()
end


function draw_switches()
    screen.move(0,10)
    screen.text "switches"

    local count = 0 -- how many switch positions have we confirmed?

    -- draw speed
    for i=1,2 do
      if screenstate[3][i] == 1 then
        count = count + 1
        screen.level(2)
        screen.rect( 74, -i*13 + 36, 12, 12)
        screen.fill()
      end
      screen.level( (screenstate[1]+1 == i) and 15 or 4 )
      screen.rect( 74, -i*13 + 36, 12, 12)
      screen.stroke()
    end

    -- draw tsc
    for i=1,3 do
      if screenstate[4][i] == 1 then
        count = count + 1
        screen.level(2)
        screen.rect( i*13 + 14, 30, 12, 12)
        screen.fill()
      end
      screen.level( (screenstate[2] == i) and 15 or 4 )
      screen.rect( i*13 + 14, 30, 12, 12)
      screen.stroke()
    end
    
    screen.level(2)
    screen.move(128, 52)
    screen.text_right( "move switches to all positions" )
    
    ok_disabled = (count ~= 5)
    draw_add_okfail()
end


function draw_mod_outline()
    screen.level(2)
    screen.rect(48,-1,80,63)
    screen.stroke()
end

function draw_mod_outs(bright)
    screen.level(bright)
    screen.move(59,54) -- avoids connecting line
    -- main outs
    for i=1,6 do
        screen.circle(42 + i*13,54,5)
        screen.stroke()
    end
    -- MIX
    screen.circle(120,17,5)
    screen.stroke()
    -- leds
    screen.level(1)
    for i=1,6 do
        screen.circle(42 + i*13,44,1)
        screen.stroke()
    end
end

function draw_mod_trs(bright,sel)
    screen.move(59,30) -- avoids connecting line
    for i=1,6 do
        if i < sel then
            screen.level(1)
            screen.circle(42 + i*13,30,5)
            screen.fill()
        end
        screen.level(bright)
        screen.circle(42 + i*13,30,5)
        screen.stroke()
    end
    -- draw selection
    if sel > 0 then
        screen.level(15)
        screen.circle(42 + sel*13,30,6)
        screen.stroke()
    end
end

function draw_mod_cvs(bright)
    screen.level(bright)
    --screen.move(59,30) -- avoids connecting line
    
    -- run, ramp, fm
    for i=1,3 do
        screen.circle(42 + i*13,23 - i*6,5)
        screen.stroke()
    end
    -- intone, time
    for i=1,2 do
        screen.circle(26 + 42 + i*13,23 - i*6,5)
        screen.stroke()
    end
    -- curve
    screen.circle(107,17,5)
    screen.stroke()
end


function draw_cvs()
    screen.move(0,40)
    screen.text "cvs"
end


function draw_trs()
    screen.move(0,10)
    screen.text "triggers"
    
    draw_mod_outs(1)
    draw_mod_trs(4,2)
    draw_mod_cvs(1)
    draw_mod_outline()
end


function draw_outs()
    screen.move(0,40)
    screen.text "outs"
end


function draw_report()
    local r = log_report()
    for k,v in ipairs(r) do
        screen.level( k==1 and 15 or 7 )
        screen.move( k==1 and 0 or 8, k*8 )
        screen.text( v )
    end
end


function draw_add_okfail()
    screen.level(15)
    screen.font_size(8)
    screen.move(0,60)
    screen.text "fail"
    screen.level(ok_disabled and 2 or 15)
    screen.move(28,60)
    screen.text "ok"
end




------------------------------------------------------
--- repl helpers

function pwr()
    crow.send "test_power(1)"
end

function rst()
    os.execute "st-flash reset"
end

function flash()
    ctest_flash( FIRMWARE, FLASH_ADDRESS )
end



globals() -- sets up global params *after* the script is fully loaded