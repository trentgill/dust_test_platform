
function draw_start()
    screen.level(15)
    screen.move(0,8)
    screen.text "just friends test"

    screen.level(15)
    screen.move(0,60)
    screen.text "start"
end

function draw_flash()
    screen.move(0,8)
    screen.text "writing firmware..."

    screen.move(8,32)
    screen.text "wait 10seconds."
end


function draw_intensity()
    ok_disabled = false
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

function draw_mod_outs(bright,sel)
    sel = sel or 0
    screen.move(59,54) -- avoids connecting line
    -- main outs
    for i=1,6 do
        if i < sel then
            screen.level(1)
            screen.circle(42 + i*13,54,5)
            screen.fill()
        end
    	screen.level(bright)
        screen.circle(42 + i*13,54,5)
        screen.stroke()
    end
    -- MIX
    screen.level(bright)
    screen.circle(120,17,5)
    screen.stroke()
    -- leds
    screen.level(1)
    for i=1,6 do
        screen.circle(42 + i*13,44,1)
        screen.stroke()
    end

    -- draw selection
    if sel > 0 and sel < 7 then
        screen.level(15)
        screen.circle(42 + sel*13,54,5)
	screen.stroke()
    elseif sel == 7 then
        screen.level(15)
        screen.circle(120,17,5)
	screen.stroke()
    end
end

function draw_mod_trs(bright,sel)
    sel = sel or 0
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

function draw_mod_cvs(bright,sel)
    sel = sel or 0
    --screen.move(59,30) -- avoids connecting line
    
    -- run, ramp, fm
    for i=1,3 do
        if i < sel then
            screen.level(1)
            screen.circle(42 + i*13,23 - i*6,5)
            screen.fill()
        end
        screen.level(bright)
        screen.circle(42 + i*13,23 - i*6,5)
        screen.stroke()
    end
    -- intone, time
    for i=1,2 do
        if (i+3) < sel then
            screen.level(1)
            screen.circle(26 + 42 + i*13,23 - i*6,5)
            screen.fill()
        end
        screen.level(bright)
        screen.circle(26 + 42 + i*13,23 - i*6,5)
        screen.stroke()
    end
    -- curve
    screen.level(bright)
    screen.circle(107,17,5)
    screen.stroke()
    
    -- draw selection
    if sel > 0 then
        screen.level(15)
        if sel < 4 then
            screen.circle(42 + sel*13,23 - sel*6,5)
        elseif sel < 6 then
            screen.circle(26 + 42 + (sel-3)*13,23 - (sel-3)*6,5)
        elseif sel == 6 then
            screen.circle(107,17,5)
        end
        screen.stroke()
    end
end


function draw_cvs()
    screen.move(0,16)
    screen.text "cvs"
    
    draw_mod_outs(1)
    draw_mod_trs(1)
    draw_mod_cvs(4,screenstate[1])
    draw_mod_outline()
    
    screen.move(0,32)
    screen.text(screenstate[1])
    screen.move(16,32)
    screen.text(screenstate[2])
    screen.move(0,40)
    screen.text(screenstate[3])

    local volt = screenstate[3]/65535
    volt = volt * 42 * 2
    screen.level(1)

    screen.move(1,44)
    screen.line(1,50)
    screen.stroke()

    screen.move(43,44)
    screen.line(43,50)
    screen.stroke()
    
    screen.level(15)
    screen.move(1+volt,44)
    screen.line(1+volt,50)
    screen.stroke()

    ok_disabled = true
    draw_add_okfail()
end


function draw_trs()
    screen.move(0,32)
    screen.text "triggers"
    
    draw_mod_outs(1)
    draw_mod_trs(4,screenstate[1])--,screenstate[]) --------- TODO
    draw_mod_cvs(1)
    draw_mod_outline()
    
    screen.move(0,40)
    screen.text(screenstate[2])

    ok_disabled = true
    draw_add_okfail()
end


function draw_outs()
    screen.move(0,48)
    screen.text "outs"
    
    draw_mod_outs(4,screenstate[1])
    draw_mod_trs(1)
    draw_mod_cvs(1)
    draw_mod_outline()
    
    screen.move(0,40)
    screen.text(screenstate[3])

    ok_disabled = true
    draw_add_okfail()
end

function draw_progress(amount)
    screen.level(1)

    screen.move(8,26)
    screen.line(8,38)
    screen.stroke()

    screen.move(120,26)
    screen.line(120,38)
    screen.stroke()
    
    amount = amount * 112

    screen.level(15)
    screen.move(8+amount,26)
    screen.line(8+amount,38)
    screen.stroke()
end

function draw_calibrate()
    screen.move(0,8)
    screen.text "calibrating..."

    draw_progress(screenstate[1])

    ok_disbled = true
end


function draw_report()
    local r = log_report()
    for k,v in ipairs(r) do
        if k < 7 then
            screen.level( k==1 and 15 or 7 )
            screen.move( k==1 and 0 or 8, k*8 )
            screen.text( v )
        end
    end
    screen.level(15)
    screen.move(0,60)
    screen.text "ok"
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
