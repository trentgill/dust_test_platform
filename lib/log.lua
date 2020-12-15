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
        --s[2] = "name   expect   got"
        for k,v in ipairs(errors) do
            s[k+1] = v[1] .. ":   " .. v[2] .. ",    " .. v[3]
            --s[k+2] = v[1] .. ":   " .. v[2] .. ",    " .. v[3]
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
