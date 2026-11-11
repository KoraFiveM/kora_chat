local H = { passed = 0, failed = 0 }

function H.test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        H.passed = H.passed + 1
        print(('  [PASS] %s'):format(name))
    else
        H.failed = H.failed + 1
        print(('  [FAIL] %s: %s'):format(name, tostring(err)))
    end
end

function H.equal(actual, expected, message)
    if actual ~= expected then error(message or ('expected %s, got %s'):format(tostring(expected), tostring(actual)), 2) end
end

function H.truthy(value, message)
    if not value then error(message or 'expected truthy value', 2) end
end

function H.falsy(value, message)
    if value then error(message or 'expected falsy value', 2) end
end

function H.report(name)
    print(('%s: %d passed, %d failed'):format(name, H.passed, H.failed))
    if H.failed > 0 then os.exit(1) end
end

return H
