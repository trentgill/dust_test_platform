repl = {}


function pwr()
    crow.send "test_power(1)"
end


function rst()
    os.execute "st-flash reset"
end


function flash()
    ctest_flash( FIRMWARE, FLASH_ADDRESS )
end


return repl