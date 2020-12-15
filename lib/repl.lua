repl = {}


function pwr()
    ctest_power(true)
end


function rst()
    os.execute "st-flash reset"
end


function flash()
    ctest_flash( FIRMWARE, FLASH_ADDRESS )
end


return repl