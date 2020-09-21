--- Just Friends Test

clk_id = {}
errors = {} -- TODO fill with table of strings to display to tester, one per error
rxd = 0
expectation = 0
window = 0
VERBOSE = true -- prints every test

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


function init()
    ctest_reset() -- reset crow environment. TODO more extreme?
    clk_id = clock.run(begin_test) -- TODO this should be managed by the norns UI
end

function ctest_reset()
    crow.send "test_amps(0)"
    crow.send "test_source(0)"
    crow.send "test_dest(0)"
end

function pwr()
    crow.send "test_power(1)"
end


-----------------------------------------------------------------------------
--- test cases { ctest_sources, expectation, window }

-- 'critical' will be run individually & will power-down immediately if any test fails
current_draw =
    { { "+12A", 1.24, 0.1 }
    , { "-12A", 0.67, 0.1 }
    }

base_volts =                     -- VMeter
    { { "+12V"    ,  3.76, 0.3 } --  11.59 => 3v77 (/3)
    , { "-12V"    , -3.61, 0.3 } -- -11.86 => -3v6 (/3)
    , { "+3V3"    ,  3.27, 0.2 } --  FIXME this pin is misaligned bw DUT/JF board
    , { "+3V1"    ,  3.01, 0.2 } --  3.10
    , { "vref_in" , -1.39, 0.2 } -- -1.50
    , { "vref_out",  1.34, 0.2 } --  1.30
    , { "-5V"     , -4.80, 0.3 } -- -4.99
    }

-- st-flash write $(BIN) 0x08008000
-- st-flash --reset write ~/dev/Just-Friends/JF_v4_0_0.bin 0x08008000

function begin_test()
    -- a series of coroutines (using the clock system++) where each tests a set of functionality and returns when the test is complete, returning pass/fail potentially with an error message
    log_clear()
    ctest_power(true)
    if ctest_suite( current_draw ) ~= 'fail' then -- test for over/under current PSU
        ctest_suite( base_volts ) -- run basic tests (+/-12V, digi V, vrefs)
        print(os.execute "st-flash --reset write ~/dev/Just-Friends/JF_v4_0_0.bin 0x08008000")
        -- flash firmware (progress bar? grep straight from the CLI?)
        -- set ii.jf.test_mode(1)
        -- ii.jf.get 'UID' -- for device tracking / logging
        -- TBC -> this is where the interactive bit happens
    end
    ctest_power(false)
    log_print()
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
        run_test_case( v )
    end
end


-- critical test, will return early on any failed test
function ctest_critical( cases )
    for k,v in ipairs( cases ) do
        local errstate = run_test_case( v )
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


function run_test_case( case )
    set_source( case[1] )
    -- accept value by reassigning event callback
    -- FIXME TODO this seems like it will be the same for every test!
    crow.input[1].stream = function(v)
            rxd = v              -- save reading
            clock.resume(clk_id) -- jump back to test
        end
    rxd = false -- unset truthiness so we can ensure we've read a value
    expectation = case[2]
    window = case[3]
    crow.input[1].query() -- request the value from crow
    clock.suspend()    -- wait for response! should instead set a time as a timeout
    -- TODO add timeout & retry

    -- clock.resume triggered by response to input[1].query()
    if rxd then -- TODO this will catch a timeout, rather than a response
        local minw = expectation-window
        local maxw = expectation+window
        if rxd > minw and rxd < maxw then -- in range
            if VERBOSE then
                print("OK! at test: "..case[1]) -- print test name
                print("  expected: ("..minw.." .. "..maxw..")")
                print("  received: "..rxd)
            end
            return
        else -- out of range
            print("FAIL! at test: "..case[1]) -- print test name
            print("  expected: ("..minw.." .. "..maxw..")")
            print("  received: "..rxd)
            log_error "out of range"
        end
    else
        print "Error: value was not returned from crow"
    end
    
    return 'fail'
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

function log_print()
    local count = #errors
    if count > 0 then
       print(count .. " TESTS FAILED!")
        for i=1,count do
            print(errors[i])
        end
    else
        print("ALL TESTS PASSED :)")
    end
end