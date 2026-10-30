; Generated game data - do not edit.
; The slope programs of the six races (71 distinct bodies) and a table per race.
; In: d0.w = cell code 0-73. Uses d0-d1/a0-a1.
slope:
        movea.l G_SLTAB(a6),a0
        tst.b   M_SLOT+1(a4)
        beq.s   .pl
        movea.l G_SLTABO(a6),a0       ; an object's programs
.pl:    add.w   d0,d0
        move.w  0(a0,d0.w),d0
        lea     slp_base(pc),a0
        jmp     0(a0,d0.w)
slp_tab0:
        dc.w    slp_p0-slp_base,slp_p1-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p3-slp_base,slp_p15-slp_base,slp_p15-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p1-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p16-slp_base,slp_p17-slp_base,slp_p18-slp_base,slp_p19-slp_base,slp_p20-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p2-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p3-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p1-slp_base,slp_p4-slp_base,slp_p23-slp_base,slp_p24-slp_base,slp_p25-slp_base,slp_p26-slp_base,slp_p3-slp_base,slp_p3-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p3-slp_base,slp_p27-slp_base,slp_p28-slp_base,slp_p29-slp_base,slp_p2-slp_base
        dc.w    slp_p1-slp_base,slp_p6-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p3-slp_base
        dc.w    slp_p3-slp_base,slp_p14-slp_base
slp_tab1:
        dc.w    slp_p0-slp_base,slp_p1-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p3-slp_base,slp_p15-slp_base,slp_p15-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p1-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p30-slp_base,slp_p31-slp_base,slp_p32-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p2-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p3-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p1-slp_base,slp_p4-slp_base,slp_p23-slp_base,slp_p24-slp_base,slp_p25-slp_base,slp_p26-slp_base,slp_p3-slp_base,slp_p3-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p3-slp_base,slp_p27-slp_base,slp_p28-slp_base,slp_p29-slp_base,slp_p2-slp_base
        dc.w    slp_p1-slp_base,slp_p6-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p3-slp_base
        dc.w    slp_p3-slp_base,slp_p14-slp_base
slp_tab2:
        dc.w    slp_p0-slp_base,slp_p1-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p3-slp_base,slp_p15-slp_base,slp_p15-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p1-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p30-slp_base,slp_p31-slp_base,slp_p32-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p2-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p3-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p1-slp_base,slp_p4-slp_base,slp_p23-slp_base,slp_p24-slp_base,slp_p25-slp_base,slp_p26-slp_base,slp_p3-slp_base,slp_p3-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p3-slp_base,slp_p27-slp_base,slp_p28-slp_base,slp_p29-slp_base,slp_p2-slp_base
        dc.w    slp_p1-slp_base,slp_p6-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p3-slp_base
        dc.w    slp_p3-slp_base,slp_p14-slp_base
slp_tab3:
        dc.w    slp_p0-slp_base,slp_p35-slp_base,slp_p36-slp_base,slp_p3-slp_base,slp_p37-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p38-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p3-slp_base,slp_p39-slp_base,slp_p39-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p35-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p40-slp_base,slp_p41-slp_base,slp_p32-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p37-slp_base
        dc.w    slp_p38-slp_base,slp_p38-slp_base,slp_p36-slp_base,slp_p38-slp_base,slp_p38-slp_base,slp_p38-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p3-slp_base,slp_p37-slp_base,slp_p37-slp_base,slp_p38-slp_base,slp_p37-slp_base,slp_p37-slp_base,slp_p37-slp_base,slp_p37-slp_base
        dc.w    slp_p35-slp_base,slp_p37-slp_base,slp_p23-slp_base,slp_p24-slp_base,slp_p25-slp_base,slp_p26-slp_base,slp_p3-slp_base,slp_p3-slp_base
        dc.w    slp_p8-slp_base,slp_p38-slp_base,slp_p37-slp_base,slp_p3-slp_base,slp_p27-slp_base,slp_p28-slp_base,slp_p29-slp_base,slp_p36-slp_base
        dc.w    slp_p35-slp_base,slp_p6-slp_base,slp_p36-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p3-slp_base
        dc.w    slp_p3-slp_base,slp_p14-slp_base
slp_tab4:
        dc.w    slp_p42-slp_base,slp_p43-slp_base,slp_p44-slp_base,slp_p3-slp_base,slp_p45-slp_base,slp_p46-slp_base,slp_p47-slp_base,slp_p48-slp_base
        dc.w    slp_p49-slp_base,slp_p50-slp_base,slp_p51-slp_base,slp_p52-slp_base,slp_p53-slp_base,slp_p54-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p3-slp_base,slp_p55-slp_base,slp_p55-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p43-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p56-slp_base,slp_p57-slp_base,slp_p32-slp_base,slp_p58-slp_base,slp_p59-slp_base,slp_p45-slp_base
        dc.w    slp_p48-slp_base,slp_p48-slp_base,slp_p44-slp_base,slp_p48-slp_base,slp_p48-slp_base,slp_p48-slp_base,slp_p60-slp_base,slp_p61-slp_base
        dc.w    slp_p3-slp_base,slp_p45-slp_base,slp_p45-slp_base,slp_p48-slp_base,slp_p45-slp_base,slp_p45-slp_base,slp_p45-slp_base,slp_p45-slp_base
        dc.w    slp_p43-slp_base,slp_p45-slp_base,slp_p23-slp_base,slp_p24-slp_base,slp_p25-slp_base,slp_p26-slp_base,slp_p3-slp_base,slp_p3-slp_base
        dc.w    slp_p49-slp_base,slp_p48-slp_base,slp_p45-slp_base,slp_p3-slp_base,slp_p27-slp_base,slp_p28-slp_base,slp_p29-slp_base,slp_p44-slp_base
        dc.w    slp_p43-slp_base,slp_p47-slp_base,slp_p44-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p49-slp_base,slp_p50-slp_base,slp_p3-slp_base
        dc.w    slp_p3-slp_base,slp_p14-slp_base
slp_tab5:
        dc.w    slp_p0-slp_base,slp_p1-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p3-slp_base,slp_p15-slp_base,slp_p15-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p1-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p30-slp_base,slp_p31-slp_base,slp_p32-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p2-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p3-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p1-slp_base,slp_p4-slp_base,slp_p23-slp_base,slp_p24-slp_base,slp_p25-slp_base,slp_p26-slp_base,slp_p3-slp_base,slp_p3-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p3-slp_base,slp_p27-slp_base,slp_p28-slp_base,slp_p29-slp_base,slp_p2-slp_base
        dc.w    slp_p1-slp_base,slp_p6-slp_base,slp_p2-slp_base,slp_p3-slp_base,slp_p3-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p3-slp_base
        dc.w    slp_p3-slp_base,slp_p14-slp_base
slp_tabo0:
        dc.w    slp_p0-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p16-slp_base,slp_p63-slp_base,slp_p18-slp_base,slp_p19-slp_base,slp_p20-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p14-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p62-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p14-slp_base,slp_p4-slp_base,slp_p64-slp_base,slp_p65-slp_base,slp_p66-slp_base,slp_p67-slp_base,slp_p62-slp_base,slp_p62-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p62-slp_base,slp_p27-slp_base,slp_p68-slp_base,slp_p29-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p6-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p62-slp_base
        dc.w    slp_p62-slp_base,slp_p14-slp_base
slp_tabo1:
        dc.w    slp_p0-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p30-slp_base,slp_p69-slp_base,slp_p70-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p14-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p62-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p14-slp_base,slp_p4-slp_base,slp_p64-slp_base,slp_p65-slp_base,slp_p66-slp_base,slp_p67-slp_base,slp_p62-slp_base,slp_p62-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p62-slp_base,slp_p27-slp_base,slp_p68-slp_base,slp_p29-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p6-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p62-slp_base
        dc.w    slp_p62-slp_base,slp_p14-slp_base
slp_tabo2:
        dc.w    slp_p0-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p30-slp_base,slp_p69-slp_base,slp_p70-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p14-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p62-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p14-slp_base,slp_p4-slp_base,slp_p64-slp_base,slp_p65-slp_base,slp_p66-slp_base,slp_p67-slp_base,slp_p62-slp_base,slp_p62-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p62-slp_base,slp_p27-slp_base,slp_p68-slp_base,slp_p29-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p6-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p62-slp_base
        dc.w    slp_p62-slp_base,slp_p14-slp_base
slp_tabo3:
        dc.w    slp_p0-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p37-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p38-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p40-slp_base,slp_p69-slp_base,slp_p70-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p37-slp_base
        dc.w    slp_p38-slp_base,slp_p38-slp_base,slp_p14-slp_base,slp_p38-slp_base,slp_p38-slp_base,slp_p38-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p62-slp_base,slp_p37-slp_base,slp_p37-slp_base,slp_p38-slp_base,slp_p37-slp_base,slp_p37-slp_base,slp_p37-slp_base,slp_p37-slp_base
        dc.w    slp_p14-slp_base,slp_p37-slp_base,slp_p64-slp_base,slp_p65-slp_base,slp_p66-slp_base,slp_p67-slp_base,slp_p62-slp_base,slp_p62-slp_base
        dc.w    slp_p8-slp_base,slp_p38-slp_base,slp_p37-slp_base,slp_p62-slp_base,slp_p27-slp_base,slp_p68-slp_base,slp_p29-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p6-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p62-slp_base
        dc.w    slp_p62-slp_base,slp_p14-slp_base
slp_tabo4:
        dc.w    slp_p42-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p45-slp_base,slp_p46-slp_base,slp_p47-slp_base,slp_p48-slp_base
        dc.w    slp_p49-slp_base,slp_p50-slp_base,slp_p51-slp_base,slp_p52-slp_base,slp_p53-slp_base,slp_p54-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p56-slp_base,slp_p69-slp_base,slp_p70-slp_base,slp_p58-slp_base,slp_p59-slp_base,slp_p45-slp_base
        dc.w    slp_p48-slp_base,slp_p48-slp_base,slp_p14-slp_base,slp_p48-slp_base,slp_p48-slp_base,slp_p48-slp_base,slp_p60-slp_base,slp_p61-slp_base
        dc.w    slp_p62-slp_base,slp_p45-slp_base,slp_p45-slp_base,slp_p48-slp_base,slp_p45-slp_base,slp_p45-slp_base,slp_p45-slp_base,slp_p45-slp_base
        dc.w    slp_p14-slp_base,slp_p45-slp_base,slp_p64-slp_base,slp_p65-slp_base,slp_p66-slp_base,slp_p67-slp_base,slp_p62-slp_base,slp_p62-slp_base
        dc.w    slp_p49-slp_base,slp_p48-slp_base,slp_p45-slp_base,slp_p62-slp_base,slp_p27-slp_base,slp_p68-slp_base,slp_p29-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p47-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p49-slp_base,slp_p50-slp_base,slp_p62-slp_base
        dc.w    slp_p62-slp_base,slp_p14-slp_base
slp_tabo5:
        dc.w    slp_p0-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p4-slp_base,slp_p5-slp_base,slp_p6-slp_base,slp_p7-slp_base
        dc.w    slp_p8-slp_base,slp_p9-slp_base,slp_p10-slp_base,slp_p11-slp_base,slp_p12-slp_base,slp_p13-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p14-slp_base,slp_p14-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p14-slp_base,slp_p30-slp_base,slp_p69-slp_base,slp_p70-slp_base,slp_p33-slp_base,slp_p34-slp_base,slp_p4-slp_base
        dc.w    slp_p7-slp_base,slp_p7-slp_base,slp_p14-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p7-slp_base,slp_p21-slp_base,slp_p22-slp_base
        dc.w    slp_p62-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base,slp_p4-slp_base
        dc.w    slp_p14-slp_base,slp_p4-slp_base,slp_p64-slp_base,slp_p65-slp_base,slp_p66-slp_base,slp_p67-slp_base,slp_p62-slp_base,slp_p62-slp_base
        dc.w    slp_p8-slp_base,slp_p7-slp_base,slp_p4-slp_base,slp_p62-slp_base,slp_p27-slp_base,slp_p68-slp_base,slp_p29-slp_base,slp_p14-slp_base
        dc.w    slp_p14-slp_base,slp_p6-slp_base,slp_p14-slp_base,slp_p62-slp_base,slp_p62-slp_base,slp_p8-slp_base,slp_p9-slp_base,slp_p62-slp_base
        dc.w    slp_p62-slp_base,slp_p14-slp_base
slp_base:
slp_p0:
.p0_0:
        tst.b   M_VXS+1(a4)
        beq.s   .p0_0_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p0_0_e
.p0_0_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p0_0_e:
.p0_1:
        tst.b   M_VYS+1(a4)
        beq.s   .p0_1_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p0_1_e
.p0_1_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p0_1_e:
.p0_2:
        rts
slp_p1:
.p1_0:
        tst.b   M_E2+1(a4)
        beq     .p1_2
.p1_1:
        subq.w  #1,M_VY(a4)
        bcc.s   .p1_1_k
        clr.w   M_VY(a4)
.p1_1_k:
.p1_2:
        tst.b   M_VXS+1(a4)
        beq.s   .p1_2_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p1_2_e
.p1_2_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p1_2_e:
.p1_3:
        rts
slp_p2:
.p2_0:
        tst.b   M_E2+1(a4)
        beq     .p2_2
.p2_1:
        subq.w  #1,M_VX(a4)
        bcc.s   .p2_1_k
        clr.w   M_VX(a4)
.p2_1_k:
.p2_2:
        tst.b   M_VYS+1(a4)
        beq.s   .p2_2_q
        moveq   #4,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p2_2_e
.p2_2_q:   moveq   #1,d1
        lea     M_VY(a4),a0
        bsr     grow
.p2_2_e:
.p2_3:
        rts
slp_p3:
.p3_0:
        tst.b   M_F7EF+1(a4)
        bne     .p3_4
.p3_1:
        tst.b   M_E2+1(a4)
        beq     .p3_4
.p3_2:
        subq.w  #2,M_VY(a4)
        bcc.s   .p3_2_k
        clr.w   M_VY(a4)
.p3_2_k:
.p3_3:
        subq.w  #2,M_VX(a4)
        bcc.s   .p3_3_k
        clr.w   M_VX(a4)
.p3_3_k:
.p3_4:
        rts
slp_p4:
.p4_0:
        tst.b   M_E2+1(a4)
        beq     .p4_2
.p4_1:
        subq.w  #1,M_VY(a4)
        bcc.s   .p4_1_k
        clr.w   M_VY(a4)
.p4_1_k:
.p4_2:
        tst.b   M_VXS+1(a4)
        beq.s   .p4_2_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p4_2_e
.p4_2_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p4_2_e:
.p4_3:
        rts
slp_p5:
.p5_0:
        subq.w  #1,M_VY(a4)
        bcc.s   .p5_0_k
        clr.w   M_VY(a4)
.p5_0_k:
.p5_1:
        tst.b   M_VXS+1(a4)
        bne.s   .p5_1_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p5_1_e
.p5_1_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p5_1_e:
.p5_2:
        rts
slp_p6:
.p6_0:
        subq.w  #1,M_VY(a4)
        bcc.s   .p6_0_k
        clr.w   M_VY(a4)
.p6_0_k:
.p6_1:
        tst.b   M_VXS+1(a4)
        bne.s   .p6_1_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p6_1_e
.p6_1_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p6_1_e:
.p6_2:
        rts
slp_p7:
.p7_0:
        tst.b   M_E2+1(a4)
        beq     .p7_2
.p7_1:
        subq.w  #1,M_VX(a4)
        bcc.s   .p7_1_k
        clr.w   M_VX(a4)
.p7_1_k:
.p7_2:
        tst.b   M_VYS+1(a4)
        beq.s   .p7_2_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p7_2_e
.p7_2_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p7_2_e:
.p7_3:
        rts
slp_p8:
.p8_0:
        subq.w  #1,M_VX(a4)
        bcc.s   .p8_0_k
        clr.w   M_VX(a4)
.p8_0_k:
.p8_1:
        tst.b   M_VYS+1(a4)
        bne.s   .p8_1_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p8_1_e
.p8_1_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p8_1_e:
.p8_2:
        rts
slp_p9:
.p9_0:
        subq.w  #1,M_VX(a4)
        bcc.s   .p9_0_k
        clr.w   M_VX(a4)
.p9_0_k:
.p9_1:
        tst.b   M_VYS+1(a4)
        bne.s   .p9_1_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p9_1_e
.p9_1_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p9_1_e:
.p9_2:
        rts
slp_p10:
.p10_0:
        tst.b   M_VYS+1(a4)
        beq.s   .p10_0_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p10_0_e
.p10_0_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p10_0_e:
.p10_1:
        tst.b   M_VXS+1(a4)
        beq.s   .p10_1_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p10_1_e
.p10_1_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p10_1_e:
.p10_2:
        rts
slp_p11:
.p11_0:
        tst.b   M_VYS+1(a4)
        beq.s   .p11_0_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p11_0_e
.p11_0_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p11_0_e:
.p11_1:
        tst.b   M_VXS+1(a4)
        beq.s   .p11_1_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p11_1_e
.p11_1_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p11_1_e:
.p11_2:
        rts
slp_p12:
.p12_0:
        tst.b   M_VYS+1(a4)
        beq.s   .p12_0_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p12_0_e
.p12_0_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p12_0_e:
.p12_1:
        tst.b   M_VXS+1(a4)
        bne.s   .p12_1_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p12_1_e
.p12_1_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p12_1_e:
.p12_2:
        rts
slp_p13:
.p13_0:
        tst.b   M_VYS+1(a4)
        beq.s   .p13_0_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p13_0_e
.p13_0_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p13_0_e:
.p13_1:
        tst.b   M_VXS+1(a4)
        bne.s   .p13_1_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p13_1_e
.p13_1_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p13_1_e:
.p13_2:
        rts
slp_p14:
.p14_0:
        rts
slp_p15:
.p15_0:
        btst    #6,M_F9D+1(a4)
        beq     .p15_5
.p15_1:
        tst.b   M_E2+1(a4)
        beq     .p15_3
.p15_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p15_2_k
        clr.w   M_VY(a4)
.p15_2_k:
.p15_3:
        tst.b   M_VXS+1(a4)
        beq.s   .p15_3_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p15_3_e
.p15_3_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p15_3_e:
.p15_4:
        bra     .p15_9
.p15_5:
        tst.b   M_F7EF+1(a4)
        bne     .p15_9
.p15_6:
        tst.b   M_E2+1(a4)
        beq     .p15_9
.p15_7:
        subq.w  #2,M_VY(a4)
        bcc.s   .p15_7_k
        clr.w   M_VY(a4)
.p15_7_k:
.p15_8:
        subq.w  #2,M_VX(a4)
        bcc.s   .p15_8_k
        clr.w   M_VX(a4)
.p15_8_k:
.p15_9:
        rts
slp_p16:
.p16_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p16_1:
        moveq   #1,d1
        bsr     slope_goal
.p16_2:
        tst.b   M_E2+1(a4)
        beq     .p16_4
.p16_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p16_3_k
        clr.w   M_VY(a4)
.p16_3_k:
.p16_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p16_4_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p16_4_e
.p16_4_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p16_4_e:
.p16_5:
        rts
slp_p17:
.p17_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p17_1:
        moveq   #1,d1
        bsr     slope_goal
.p17_2:
        tst.b   M_E2+1(a4)
        beq     .p17_4
.p17_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p17_3_k
        clr.w   M_VY(a4)
.p17_3_k:
.p17_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p17_4_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p17_4_e
.p17_4_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p17_4_e:
.p17_5:
        rts
slp_p18:
.p18_0:
        subq.w  #2,M_VX(a4)
        bcc.s   .p18_0_k
        clr.w   M_VX(a4)
.p18_0_k:
.p18_1:
        moveq   #1,d1
        bsr     slope_goal
.p18_2:
        rts
slp_p19:
.p19_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
.p19_1:
        moveq   #1,d1
        bsr     slope_goal
.p19_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p19_2_k
        clr.w   M_VY(a4)
.p19_2_k:
.p19_3:
        tst.b   M_VXS+1(a4)
        bne.s   .p19_3_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p19_3_e
.p19_3_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p19_3_e:
.p19_4:
        rts
slp_p20:
.p20_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
.p20_1:
        moveq   #1,d1
        bsr     slope_goal
.p20_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p20_2_k
        clr.w   M_VY(a4)
.p20_2_k:
.p20_3:
        tst.b   M_VXS+1(a4)
        bne.s   .p20_3_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p20_3_e
.p20_3_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p20_3_e:
.p20_4:
        rts
slp_p21:
.p21_0:
        tst.b   M_VYS+1(a4)
        bne.s   .p21_0_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p21_0_e
.p21_0_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p21_0_e:
.p21_1:
        subq.w  #8,M_VX(a4)
        bcc.s   .p21_1_k
        clr.w   M_VX(a4)
.p21_1_k:
.p21_2:
        rts
slp_p22:
.p22_0:
        tst.b   M_VXS+1(a4)
        bne.s   .p22_0_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p22_0_e
.p22_0_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p22_0_e:
.p22_1:
        subq.w  #8,M_VY(a4)
        bcc.s   .p22_1_k
        clr.w   M_VY(a4)
.p22_1_k:
.p22_2:
        rts
slp_p23:
.p23_0:
        moveq   #2,d1
        bsr     slope_pad
.p23_1:
        tst.b   M_F7EF+1(a4)
        bne     .p23_5
.p23_2:
        tst.b   M_E2+1(a4)
        beq     .p23_5
.p23_3:
        subq.w  #2,M_VY(a4)
        bcc.s   .p23_3_k
        clr.w   M_VY(a4)
.p23_3_k:
.p23_4:
        subq.w  #2,M_VX(a4)
        bcc.s   .p23_4_k
        clr.w   M_VX(a4)
.p23_4_k:
.p23_5:
        rts
slp_p24:
.p24_0:
        moveq   #3,d1
        bsr     slope_pad
.p24_1:
        tst.b   M_F7EF+1(a4)
        bne     .p24_5
.p24_2:
        tst.b   M_E2+1(a4)
        beq     .p24_5
.p24_3:
        subq.w  #2,M_VY(a4)
        bcc.s   .p24_3_k
        clr.w   M_VY(a4)
.p24_3_k:
.p24_4:
        subq.w  #2,M_VX(a4)
        bcc.s   .p24_4_k
        clr.w   M_VX(a4)
.p24_4_k:
.p24_5:
        rts
slp_p25:
.p25_0:
        moveq   #4,d1
        bsr     slope_pad
.p25_1:
        tst.b   M_F7EF+1(a4)
        bne     .p25_5
.p25_2:
        tst.b   M_E2+1(a4)
        beq     .p25_5
.p25_3:
        subq.w  #2,M_VY(a4)
        bcc.s   .p25_3_k
        clr.w   M_VY(a4)
.p25_3_k:
.p25_4:
        subq.w  #2,M_VX(a4)
        bcc.s   .p25_4_k
        clr.w   M_VX(a4)
.p25_4_k:
.p25_5:
        rts
slp_p26:
.p26_0:
        moveq   #5,d1
        bsr     slope_pad
.p26_1:
        tst.b   M_F7EF+1(a4)
        bne     .p26_5
.p26_2:
        tst.b   M_E2+1(a4)
        beq     .p26_5
.p26_3:
        subq.w  #2,M_VY(a4)
        bcc.s   .p26_3_k
        clr.w   M_VY(a4)
.p26_3_k:
.p26_4:
        subq.w  #2,M_VX(a4)
        bcc.s   .p26_4_k
        clr.w   M_VX(a4)
.p26_4_k:
.p26_5:
        rts
slp_p27:
.p27_0:
        tst.b   M_E2+1(a4)
        beq     .p27_3
.p27_1:
        subq.w  #4,M_VY(a4)
        bcc.s   .p27_1_k
        clr.w   M_VY(a4)
.p27_1_k:
.p27_2:
        subq.w  #4,M_VX(a4)
        bcc.s   .p27_2_k
        clr.w   M_VX(a4)
.p27_2_k:
.p27_3:
        rts
slp_p28:
.p28_0:
        moveq   #7,d0
        and.b   M_Y+2(a4),d0
        lea     slope_fdtab(pc),a0
        move.b  0(a0,d0.w),d0
        move.w  d0,M_FD(a4)
.p28_1:
        tst.b   M_E2+1(a4)
        beq     .p28_4
.p28_2:
        subq.w  #4,M_VY(a4)
        bcc.s   .p28_2_k
        clr.w   M_VY(a4)
.p28_2_k:
.p28_3:
        subq.w  #2,M_VX(a4)
        bcc.s   .p28_3_k
        clr.w   M_VX(a4)
.p28_3_k:
.p28_4:
        rts
slp_p29:
.p29_0:
        tst.w   M_VX(a4)
        bne.s   .p29_0_k
        moveq   #8,d1
        lea     M_VX(a4),a0
        bsr     grow
.p29_0_k:
.p29_1:
        tst.w   M_VY(a4)
        bne.s   .p29_1_k
        moveq   #8,d1
        lea     M_VY(a4),a0
        bsr     grow
.p29_1_k:
.p29_2:
        rts
slp_p30:
.p30_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p30_1:
        moveq   #1,d1
        bsr     slope_goalx
.p30_2:
        tst.b   M_E2+1(a4)
        beq     .p30_4
.p30_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p30_3_k
        clr.w   M_VY(a4)
.p30_3_k:
.p30_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p30_4_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p30_4_e
.p30_4_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p30_4_e:
.p30_5:
        rts
slp_p31:
.p31_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p31_1:
        moveq   #1,d1
        bsr     slope_goalx
.p31_2:
        tst.b   M_E2+1(a4)
        beq     .p31_4
.p31_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p31_3_k
        clr.w   M_VY(a4)
.p31_3_k:
.p31_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p31_4_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p31_4_e
.p31_4_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p31_4_e:
.p31_5:
        rts
slp_p32:
.p32_0:
        subq.w  #6,M_VY(a4)
        bcc.s   .p32_0_k
        clr.w   M_VY(a4)
.p32_0_k:
.p32_1:
        moveq   #0,d1
        bsr     slope_goalx
.p32_2:
        tst.b   M_F7EF+1(a4)
        bne     .p32_6
.p32_3:
        tst.b   M_E2+1(a4)
        beq     .p32_6
.p32_4:
        subq.w  #2,M_VY(a4)
        bcc.s   .p32_4_k
        clr.w   M_VY(a4)
.p32_4_k:
.p32_5:
        subq.w  #2,M_VX(a4)
        bcc.s   .p32_5_k
        clr.w   M_VX(a4)
.p32_5_k:
.p32_6:
        rts
slp_p33:
.p33_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
.p33_1:
        moveq   #1,d1
        bsr     slope_goalx
.p33_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p33_2_k
        clr.w   M_VY(a4)
.p33_2_k:
.p33_3:
        tst.b   M_VXS+1(a4)
        bne.s   .p33_3_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p33_3_e
.p33_3_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p33_3_e:
.p33_4:
        rts
slp_p34:
.p34_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
.p34_1:
        moveq   #1,d1
        bsr     slope_goalx
.p34_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p34_2_k
        clr.w   M_VY(a4)
.p34_2_k:
.p34_3:
        tst.b   M_VXS+1(a4)
        bne.s   .p34_3_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p34_3_e
.p34_3_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p34_3_e:
.p34_4:
        rts
slp_p35:
.p35_0:
        tst.b   M_E2+1(a4)
        beq     .p35_3
.p35_1:
        subq.w  #1,M_VY(a4)
        bcc.s   .p35_1_k
        clr.w   M_VY(a4)
.p35_1_k:
.p35_2:
        tst.b   M_VXS+1(a4)
        beq.s   .p35_2_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p35_2_e
.p35_2_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p35_2_e:
.p35_3:
        tst.b   M_E2+1(a4)
        bne     .p35_5
.p35_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p35_4_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p35_4_e
.p35_4_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p35_4_e:
.p35_5:
        rts
slp_p36:
.p36_0:
        tst.b   M_E2+1(a4)
        beq     .p36_3
.p36_1:
        subq.w  #1,M_VX(a4)
        bcc.s   .p36_1_k
        clr.w   M_VX(a4)
.p36_1_k:
.p36_2:
        tst.b   M_VYS+1(a4)
        beq.s   .p36_2_q
        moveq   #4,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p36_2_e
.p36_2_q:   moveq   #1,d1
        lea     M_VY(a4),a0
        bsr     grow
.p36_2_e:
.p36_3:
        tst.b   M_E2+1(a4)
        bne     .p36_5
.p36_4:
        tst.b   M_VYS+1(a4)
        beq.s   .p36_4_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p36_4_e
.p36_4_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p36_4_e:
.p36_5:
        rts
slp_p37:
.p37_0:
        tst.b   M_E2+1(a4)
        beq     .p37_3
.p37_1:
        subq.w  #1,M_VY(a4)
        bcc.s   .p37_1_k
        clr.w   M_VY(a4)
.p37_1_k:
.p37_2:
        tst.b   M_VXS+1(a4)
        beq.s   .p37_2_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p37_2_e
.p37_2_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p37_2_e:
.p37_3:
        tst.b   M_E2+1(a4)
        bne     .p37_5
.p37_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p37_4_q
        moveq   #64,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p37_4_e
.p37_4_q:   moveq   #16,d1
        lea     M_VX(a4),a0
        bsr     grow
.p37_4_e:
.p37_5:
        rts
slp_p38:
.p38_0:
        tst.b   M_E2+1(a4)
        beq     .p38_3
.p38_1:
        subq.w  #1,M_VX(a4)
        bcc.s   .p38_1_k
        clr.w   M_VX(a4)
.p38_1_k:
.p38_2:
        tst.b   M_VYS+1(a4)
        beq.s   .p38_2_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p38_2_e
.p38_2_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p38_2_e:
.p38_3:
        tst.b   M_E2+1(a4)
        bne     .p38_5
.p38_4:
        tst.b   M_VYS+1(a4)
        beq.s   .p38_4_q
        moveq   #64,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p38_4_e
.p38_4_q:   moveq   #16,d1
        lea     M_VY(a4),a0
        bsr     grow
.p38_4_e:
.p38_5:
        rts
slp_p39:
.p39_0:
        btst    #6,M_F9D+1(a4)
        beq     .p39_7
.p39_1:
        tst.b   M_E2+1(a4)
        beq     .p39_4
.p39_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p39_2_k
        clr.w   M_VY(a4)
.p39_2_k:
.p39_3:
        tst.b   M_VXS+1(a4)
        beq.s   .p39_3_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p39_3_e
.p39_3_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p39_3_e:
.p39_4:
        tst.b   M_E2+1(a4)
        bne     .p39_6
.p39_5:
        tst.b   M_VXS+1(a4)
        beq.s   .p39_5_q
        moveq   #64,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p39_5_e
.p39_5_q:   moveq   #16,d1
        lea     M_VX(a4),a0
        bsr     grow
.p39_5_e:
.p39_6:
        bra     .p39_11
.p39_7:
        tst.b   M_F7EF+1(a4)
        bne     .p39_11
.p39_8:
        tst.b   M_E2+1(a4)
        beq     .p39_11
.p39_9:
        subq.w  #2,M_VY(a4)
        bcc.s   .p39_9_k
        clr.w   M_VY(a4)
.p39_9_k:
.p39_10:
        subq.w  #2,M_VX(a4)
        bcc.s   .p39_10_k
        clr.w   M_VX(a4)
.p39_10_k:
.p39_11:
        rts
slp_p40:
.p40_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p40_1:
        moveq   #1,d1
        bsr     slope_goalx
.p40_2:
        tst.b   M_E2+1(a4)
        beq     .p40_5
.p40_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p40_3_k
        clr.w   M_VY(a4)
.p40_3_k:
.p40_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p40_4_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p40_4_e
.p40_4_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p40_4_e:
.p40_5:
        tst.b   M_E2+1(a4)
        bne     .p40_7
.p40_6:
        tst.b   M_VXS+1(a4)
        beq.s   .p40_6_q
        moveq   #64,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p40_6_e
.p40_6_q:   moveq   #16,d1
        lea     M_VX(a4),a0
        bsr     grow
.p40_6_e:
.p40_7:
        rts
slp_p41:
.p41_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p41_1:
        moveq   #1,d1
        bsr     slope_goalx
.p41_2:
        tst.b   M_E2+1(a4)
        beq     .p41_5
.p41_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p41_3_k
        clr.w   M_VY(a4)
.p41_3_k:
.p41_4:
        tst.b   M_VXS+1(a4)
        beq.s   .p41_4_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p41_4_e
.p41_4_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p41_4_e:
.p41_5:
        tst.b   M_E2+1(a4)
        bne     .p41_7
.p41_6:
        tst.b   M_VXS+1(a4)
        beq.s   .p41_6_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p41_6_e
.p41_6_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p41_6_e:
.p41_7:
        rts
slp_p42:
.p42_0:
        tst.b   M_VXS+1(a4)
        bne.s   .p42_0_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p42_0_e
.p42_0_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p42_0_e:
.p42_1:
        tst.b   M_VYS+1(a4)
        bne.s   .p42_1_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p42_1_e
.p42_1_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p42_1_e:
.p42_2:
        rts
slp_p43:
.p43_0:
        tst.b   M_E2+1(a4)
        beq     .p43_2
.p43_1:
        subq.w  #1,M_VY(a4)
        bcc.s   .p43_1_k
        clr.w   M_VY(a4)
.p43_1_k:
.p43_2:
        tst.b   M_VXS+1(a4)
        bne.s   .p43_2_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p43_2_e
.p43_2_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p43_2_e:
.p43_3:
        rts
slp_p44:
.p44_0:
        tst.b   M_E2+1(a4)
        beq     .p44_2
.p44_1:
        subq.w  #1,M_VX(a4)
        bcc.s   .p44_1_k
        clr.w   M_VX(a4)
.p44_1_k:
.p44_2:
        tst.b   M_VYS+1(a4)
        bne.s   .p44_2_q
        moveq   #4,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p44_2_e
.p44_2_q:   moveq   #1,d1
        lea     M_VY(a4),a0
        bsr     grow
.p44_2_e:
.p44_3:
        rts
slp_p45:
.p45_0:
        tst.b   M_E2+1(a4)
        beq     .p45_2
.p45_1:
        subq.w  #1,M_VY(a4)
        bcc.s   .p45_1_k
        clr.w   M_VY(a4)
.p45_1_k:
.p45_2:
        tst.b   M_VXS+1(a4)
        bne.s   .p45_2_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p45_2_e
.p45_2_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p45_2_e:
.p45_3:
        rts
slp_p46:
.p46_0:
        subq.w  #1,M_VY(a4)
        bcc.s   .p46_0_k
        clr.w   M_VY(a4)
.p46_0_k:
.p46_1:
        tst.b   M_VXS+1(a4)
        beq.s   .p46_1_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p46_1_e
.p46_1_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p46_1_e:
.p46_2:
        rts
slp_p47:
.p47_0:
        subq.w  #1,M_VY(a4)
        bcc.s   .p47_0_k
        clr.w   M_VY(a4)
.p47_0_k:
.p47_1:
        tst.b   M_VXS+1(a4)
        beq.s   .p47_1_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p47_1_e
.p47_1_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p47_1_e:
.p47_2:
        rts
slp_p48:
.p48_0:
        tst.b   M_E2+1(a4)
        beq     .p48_2
.p48_1:
        subq.w  #1,M_VX(a4)
        bcc.s   .p48_1_k
        clr.w   M_VX(a4)
.p48_1_k:
.p48_2:
        tst.b   M_VYS+1(a4)
        bne.s   .p48_2_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p48_2_e
.p48_2_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p48_2_e:
.p48_3:
        rts
slp_p49:
.p49_0:
        subq.w  #1,M_VX(a4)
        bcc.s   .p49_0_k
        clr.w   M_VX(a4)
.p49_0_k:
.p49_1:
        tst.b   M_VYS+1(a4)
        beq.s   .p49_1_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p49_1_e
.p49_1_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p49_1_e:
.p49_2:
        rts
slp_p50:
.p50_0:
        subq.w  #1,M_VX(a4)
        bcc.s   .p50_0_k
        clr.w   M_VX(a4)
.p50_0_k:
.p50_1:
        tst.b   M_VYS+1(a4)
        beq.s   .p50_1_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p50_1_e
.p50_1_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p50_1_e:
.p50_2:
        rts
slp_p51:
.p51_0:
        tst.b   M_VYS+1(a4)
        bne.s   .p51_0_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p51_0_e
.p51_0_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p51_0_e:
.p51_1:
        tst.b   M_VXS+1(a4)
        bne.s   .p51_1_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p51_1_e
.p51_1_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p51_1_e:
.p51_2:
        rts
slp_p52:
.p52_0:
        tst.b   M_VYS+1(a4)
        bne.s   .p52_0_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p52_0_e
.p52_0_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p52_0_e:
.p52_1:
        tst.b   M_VXS+1(a4)
        bne.s   .p52_1_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p52_1_e
.p52_1_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p52_1_e:
.p52_2:
        rts
slp_p53:
.p53_0:
        tst.b   M_VYS+1(a4)
        bne.s   .p53_0_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p53_0_e
.p53_0_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p53_0_e:
.p53_1:
        tst.b   M_VXS+1(a4)
        beq.s   .p53_1_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p53_1_e
.p53_1_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p53_1_e:
.p53_2:
        rts
slp_p54:
.p54_0:
        tst.b   M_VYS+1(a4)
        bne.s   .p54_0_q
        moveq   #16,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p54_0_e
.p54_0_q:   moveq   #4,d1
        lea     M_VY(a4),a0
        bsr     grow
.p54_0_e:
.p54_1:
        tst.b   M_VXS+1(a4)
        beq.s   .p54_1_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p54_1_e
.p54_1_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p54_1_e:
.p54_2:
        rts
slp_p55:
.p55_0:
        btst    #6,M_F9D+1(a4)
        beq     .p55_5
.p55_1:
        tst.b   M_E2+1(a4)
        beq     .p55_3
.p55_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p55_2_k
        clr.w   M_VY(a4)
.p55_2_k:
.p55_3:
        tst.b   M_VXS+1(a4)
        bne.s   .p55_3_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p55_3_e
.p55_3_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p55_3_e:
.p55_4:
        bra     .p55_9
.p55_5:
        tst.b   M_F7EF+1(a4)
        bne     .p55_9
.p55_6:
        tst.b   M_E2+1(a4)
        beq     .p55_9
.p55_7:
        subq.w  #2,M_VY(a4)
        bcc.s   .p55_7_k
        clr.w   M_VY(a4)
.p55_7_k:
.p55_8:
        subq.w  #2,M_VX(a4)
        bcc.s   .p55_8_k
        clr.w   M_VX(a4)
.p55_8_k:
.p55_9:
        rts
slp_p56:
.p56_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p56_1:
        moveq   #1,d1
        bsr     slope_goalx
.p56_2:
        tst.b   M_E2+1(a4)
        beq     .p56_4
.p56_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p56_3_k
        clr.w   M_VY(a4)
.p56_3_k:
.p56_4:
        tst.b   M_VXS+1(a4)
        bne.s   .p56_4_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p56_4_e
.p56_4_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p56_4_e:
.p56_5:
        rts
slp_p57:
.p57_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p57_1:
        moveq   #1,d1
        bsr     slope_goalx
.p57_2:
        tst.b   M_E2+1(a4)
        beq     .p57_4
.p57_3:
        subq.w  #1,M_VY(a4)
        bcc.s   .p57_3_k
        clr.w   M_VY(a4)
.p57_3_k:
.p57_4:
        tst.b   M_VXS+1(a4)
        bne.s   .p57_4_q
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p57_4_e
.p57_4_q:   moveq   #1,d1
        lea     M_VX(a4),a0
        bsr     grow
.p57_4_e:
.p57_5:
        rts
slp_p58:
.p58_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
.p58_1:
        moveq   #1,d1
        bsr     slope_goalx
.p58_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p58_2_k
        clr.w   M_VY(a4)
.p58_2_k:
.p58_3:
        tst.b   M_VXS+1(a4)
        beq.s   .p58_3_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p58_3_e
.p58_3_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p58_3_e:
.p58_4:
        rts
slp_p59:
.p59_0:
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_neg
.p59_1:
        moveq   #1,d1
        bsr     slope_goalx
.p59_2:
        subq.w  #1,M_VY(a4)
        bcc.s   .p59_2_k
        clr.w   M_VY(a4)
.p59_2_k:
.p59_3:
        tst.b   M_VXS+1(a4)
        beq.s   .p59_3_q
        moveq   #16,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p59_3_e
.p59_3_q:   moveq   #4,d1
        lea     M_VX(a4),a0
        bsr     grow
.p59_3_e:
.p59_4:
        rts
slp_p60:
.p60_0:
        tst.b   M_VYS+1(a4)
        beq.s   .p60_0_q
        moveq   #8,d1
        lea     M_VY(a4),a0
        lea     M_VYS(a4),a1
        bsr     shrink
        bra.s   .p60_0_e
.p60_0_q:   moveq   #2,d1
        lea     M_VY(a4),a0
        bsr     grow
.p60_0_e:
.p60_1:
        subq.w  #8,M_VX(a4)
        bcc.s   .p60_1_k
        clr.w   M_VX(a4)
.p60_1_k:
.p60_2:
        rts
slp_p61:
.p61_0:
        tst.b   M_VXS+1(a4)
        beq.s   .p61_0_q
        moveq   #8,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     shrink
        bra.s   .p61_0_e
.p61_0_q:   moveq   #2,d1
        lea     M_VX(a4),a0
        bsr     grow
.p61_0_e:
.p61_1:
        subq.w  #8,M_VY(a4)
        bcc.s   .p61_1_k
        clr.w   M_VY(a4)
.p61_1_k:
.p61_2:
        rts
slp_p62:
.p62_0:
        subq.w  #2,M_VY(a4)
        bcc.s   .p62_0_k
        clr.w   M_VY(a4)
.p62_0_k:
.p62_1:
        subq.w  #2,M_VX(a4)
        bcc.s   .p62_1_k
        clr.w   M_VX(a4)
.p62_1_k:
.p62_2:
        rts
slp_p63:
.p63_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p63_1:
        moveq   #1,d1
        bsr     slope_goal
.p63_2:
        rts
slp_p64:
.p64_0:
        moveq   #2,d1
        bsr     slope_pad
.p64_1:
        subq.w  #2,M_VY(a4)
        bcc.s   .p64_1_k
        clr.w   M_VY(a4)
.p64_1_k:
.p64_2:
        subq.w  #2,M_VX(a4)
        bcc.s   .p64_2_k
        clr.w   M_VX(a4)
.p64_2_k:
.p64_3:
        rts
slp_p65:
.p65_0:
        moveq   #3,d1
        bsr     slope_pad
.p65_1:
        subq.w  #2,M_VY(a4)
        bcc.s   .p65_1_k
        clr.w   M_VY(a4)
.p65_1_k:
.p65_2:
        subq.w  #2,M_VX(a4)
        bcc.s   .p65_2_k
        clr.w   M_VX(a4)
.p65_2_k:
.p65_3:
        rts
slp_p66:
.p66_0:
        moveq   #4,d1
        bsr     slope_pad
.p66_1:
        subq.w  #2,M_VY(a4)
        bcc.s   .p66_1_k
        clr.w   M_VY(a4)
.p66_1_k:
.p66_2:
        subq.w  #2,M_VX(a4)
        bcc.s   .p66_2_k
        clr.w   M_VX(a4)
.p66_2_k:
.p66_3:
        rts
slp_p67:
.p67_0:
        moveq   #5,d1
        bsr     slope_pad
.p67_1:
        subq.w  #2,M_VY(a4)
        bcc.s   .p67_1_k
        clr.w   M_VY(a4)
.p67_1_k:
.p67_2:
        subq.w  #2,M_VX(a4)
        bcc.s   .p67_2_k
        clr.w   M_VX(a4)
.p67_2_k:
.p67_3:
        rts
slp_p68:
.p68_0:
        tst.b   M_E2+1(a4)
        beq     .p68_3
.p68_1:
        subq.w  #4,M_VY(a4)
        bcc.s   .p68_1_k
        clr.w   M_VY(a4)
.p68_1_k:
.p68_2:
        subq.w  #2,M_VX(a4)
        bcc.s   .p68_2_k
        clr.w   M_VX(a4)
.p68_2_k:
.p68_3:
        rts
slp_p69:
.p69_0:
        moveq   #4,d1
        lea     M_VX(a4),a0
        lea     M_VXS(a4),a1
        bsr     accel_pos
.p69_1:
        moveq   #1,d1
        bsr     slope_goalx
.p69_2:
        rts
slp_p70:
.p70_0:
        subq.w  #6,M_VY(a4)
        bcc.s   .p70_0_k
        clr.w   M_VY(a4)
.p70_0_k:
.p70_1:
        moveq   #0,d1
        bsr     slope_goalx
.p70_2:
        subq.w  #2,M_VY(a4)
        bcc.s   .p70_2_k
        clr.w   M_VY(a4)
.p70_2_k:
.p70_3:
        subq.w  #2,M_VX(a4)
        bcc.s   .p70_3_k
        clr.w   M_VX(a4)
.p70_3_k:
.p70_4:
        rts
