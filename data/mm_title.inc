; Generated game data - do not edit.
; The loading screen's text (mm_scr outside the logo): per string word screen
; offset (line x 128 + byte), the colour words of its first line and the next, word cells - 1,
; the cells' glyphs (bytes, even); word -1. Then 8 B a glyph (bit 7 = left), and the
; masks of a glyph row's 4-pixel halves (16 words).
mm_title:
        dc.w    7180,$AAFF,$AAFF,25
        dc.b    0,1,2,1,3,1,4,1,5,1,6,1,1,7,1,8,1,9,1,10,1,3,1,11,1,12
        even
        dc.w    9264,$AAFF,$AAFF,7
        dc.b    13,8,11,14,11,6,4,14
        even
        dc.w    25648,$AAAA,$AABB,6
        dc.b    3,5,9,10,2,6,15
        even
        dc.w    28712,$AAFF,$AAFF,12
        dc.b    16,1,17,18,19,20,1,4,11,6,15,11,6
        even
        dc.w    29724,$AAFF,$AAFF,17
        dc.b    21,3,1,13,5,8,4,1,7,12,1,22,23,0,24,25,9,12
        even
        dc.w    -1
tt_glyphs:
        dc.b    $00,$C6,$EE,$FE,$D6,$D6,$C6,$C6
        dc.b    $00,$00,$00,$00,$00,$00,$00,$00
        dc.b    $00,$7E,$18,$18,$18,$18,$18,$7E
        dc.b    $00,$C0,$C0,$C0,$C0,$C0,$C0,$FE
        dc.b    $00,$FC,$30,$30,$30,$30,$30,$30
        dc.b    $00,$7C,$C6,$C6,$C6,$C6,$C6,$7C
        dc.b    $00,$C6,$E6,$F6,$DE,$CE,$C6,$C6
        dc.b    $00,$FC,$C6,$C6,$FC,$C6,$C6,$FC
        dc.b    $00,$FC,$C6,$C6,$FC,$CE,$C6,$C6
        dc.b    $00,$7C,$C6,$C6,$FE,$C6,$C6,$C6
        dc.b    $00,$F8,$CC,$C6,$C6,$C6,$CC,$F8
        dc.b    $00,$FE,$C0,$C0,$F8,$C0,$C0,$FE
        dc.b    $00,$CC,$CC,$CC,$78,$30,$30,$30
        dc.b    $00,$FC,$C6,$C6,$FC,$C0,$C0,$C0
        dc.b    $00,$7C,$C6,$C0,$7C,$06,$C6,$7C
        dc.b    $00,$7C,$C6,$C0,$C0,$CE,$C6,$7C
        dc.b    $3C,$42,$9D,$B1,$B1,$9D,$42,$3C
        dc.b    $00,$18,$38,$18,$18,$18,$18,$3C
        dc.b    $00,$7C,$C6,$C6,$7E,$06,$C6,$7C
        dc.b    $00,$7C,$C6,$C6,$7C,$C6,$C6,$7C
        dc.b    $00,$1C,$3C,$6C,$CC,$FE,$0C,$0C
        dc.b    $00,$7C,$C6,$C6,$C6,$DA,$CC,$76
        dc.b    $00,$FE,$0C,$0C,$CC,$CC,$CC,$78
        dc.b    $00,$00,$00,$00,$00,$00,$18,$18
        dc.b    $00,$7C,$C6,$C0,$C0,$C0,$C6,$7C
        dc.b    $00,$C6,$C6,$CC,$F8,$CC,$C6,$C6
tt_mask:
        dc.w    $0000,$0303,$0C0C,$0F0F,$3030,$3333,$3C3C,$3F3F,$C0C0,$C3C3,$CCCC,$CFCF,$F0F0,$F3F3,$FCFC,$FFFF
