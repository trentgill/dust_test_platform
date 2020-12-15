--- Just Friends Test

include "lib/draw"
include "lib/repl"
include "lib/log"


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
        print "current draw ok."
        ctest_suite( operating_points )
        print "operating points done."
        --VERBOSE = true
        local flash_ok = 1
        print("force flash = "..tostring(force_flash))
        print("ctest has flash = "..tostring(ctest_has_flash()))
        if force_flash or not ctest_has_flash() then
            print "start flash."
            --_, _, flash_ok = ctest_flash( FIRMWARE, FLASH_ADDRESS )
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
    --test_jacks_tr()
    --test_jacks_outs()
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
    
    crow.output[1].volts = 0
    
    crow.ii.jf.event = function( e, v )
        if rxd ~= 0 then
            if v == 0 and screenstate[1] == 0 then -- check for zero
                crow.output[1].volts = 5
                screenstate[1] = 1
            end
            screenstate[2] = v -- save current state
            if v == screenstate[1] then
                screenstate[1] = screenstate[1] + 1
            end
            if screenstate[1] == 7 then
                guide_status = ""
                async_resume(0)
                return
            end
            rxd = 0
            redraw()
        end
    end
    
    -- start streaming tr values from DUT
    local query = clock.run(function()
        while true do
            rxd = 1
            ctest_iiget( iiget.sTrigger )
            clock.sleep(0.02)
        end
    end)

    screenstate = {0,0} -- start at left
    set_screen "trs"
    
    guide_status = "jacks_tr"
    redraw()
    suspend_with_timeout(60)
    
    clock.cancel(query) -- stop streaming
    
    set_dest "none" -- deactivate output jack
end



function test_jacks_outs()
    -- test output jacks with patch cable
    set_source "jack"
    crow.send( "ii.jf.test(19)" ) -- start chan 1 at 3rd setting (+ve test)
    
    --crow.send( "ii.jf.test(".. iiset.lights[cmd] ..")" ) -- cmd is 1..4 (0v, 0.7V, 5V, -2V)?
    -- 1 == .041, .057, .013, .044, .033, .021  { .013 ..  .057}
    -- 2 == .561, .574, .534, .569, .548, .537  { .534 ..  .574}
    -- 3 == 8.36, 8.32, 8.35, 8.45, 8.26, 8.28  { 8.26 ..  8.36}
    -- 4 == -1.62 -1.60 -1.65 -1.64 -1.61 -1.63 {-1.65 .. -1.60}
    local expectations = { 4, 0, -4 } -- TODO accurate calibrate these vals
    
    -- test(17) == out[1] @-5v
    
    --crow.ii.jf.event = function( e, v )
    crow.input[1].stream = function( v )
        v = v-0.082 -- FIXME hacked offset bc no calibration on crow

        screenstate[3] = v -- save current voltage
        local expect = expectations[screenstate[2]]
        local expect_min = expect - 0.15
        local expect_max = expect + 0.15
        if v > expect_min and v < expect_max then -- match value
            screenstate[2] = screenstate[2] + 1
            if screenstate[2] >= 4 then
                screenstate[2] = 1
                screenstate[1] = screenstate[1] + 1
                if screenstate[1] >= 8 then
                    guide_status = ""
                    async_resume(0)
                    return
                end
            end
            -- count +ve first for a visual guide
            local index = 17+(screenstate[1]*3)-screenstate[2]
            crow.send( "ii.jf.test(".. index .. ")" ) -- update test setting
        end
        redraw()
    end
    
    -- start streaming tr values from DUT
    local query = clock.run(function()
        while true do
            --ctest_iiget( iiget.sTrigger )
            crow.input[1].query()
            clock.sleep(0.02)
        end
    end)

    screenstate = {1,1,0} -- {output_ix, output_setting, value}
    set_screen "outs"
    
    guide_status = "jacks_outs"
    redraw()
    suspend_with_timeout(60)
    
    clock.cancel(query) -- stop streaming
    
    set_dest "none" -- deactivate output jack
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




globals() -- sets up global params *after* the script is fully loaded