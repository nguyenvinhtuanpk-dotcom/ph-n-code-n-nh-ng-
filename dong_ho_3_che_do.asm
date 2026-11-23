; ===================================================================
; DONG HO DA NANG 3 CHE DO - AT89C51 (THACH ANH 12MHz)
; So do phan cung (Proteus):
;   LED 7 doan 4 so Cathode Chung (Muc 1 sang net, Muc 0 chon LED):
;     P2.0..P2.7 -> A, B, C, D, E, F, G, DP
;     P3.0 -> Chan 4 (LED ngoai cung ben phai)
;     P3.1 -> Chan 3
;     P3.2 -> Chan 2 (co dau cham DP luon sang co dinh)
;     P3.3 -> Chan 1 (LED ngoai cung ben trai)
;   4 nut bam (kich muc 0, co dien tro keo len):
;     P1.0 -> START
;     P1.1 -> ADJUST
;     P1.2 -> RESET
;     P1.3 -> MODE
;
; 3 CHE DO:
;   Mode 1 (CUR_MODE = 0): Dong ho thoi gian thuc 24h (HH:MM, 00:00-23:59)
;   Mode 2 (CUR_MODE = 1): Dem xuoi / Bam gio         (MM:SS, 00:00-59:59)
;   Mode 3 (CUR_MODE = 2): Dem nguoc                  (MM:SS, 00:00-59:59)
; ===================================================================
        ORG 0000H
        LJMP MAIN
        ORG 000BH               ; Vector ngat Timer 0 (5ms)
        LJMP T0_ISR
; ===================================================================
; KHAI BAO CO (BIT-ADDRESSABLE RAM 20H) VA BIEN RAM (30H - 45H)
; ===================================================================
FLAG_EDIT    BIT 20H.0          ; 0 = Non-edit, 1 = Edit (Mode 1 & Mode 3)
FLAG_FIELD   BIT 20H.1          ; 0 = Chinh cap phai (MM/SS), 1 = Chinh cap trai (HH/MM)
FLAG_CLK_RUN BIT 20H.2          ; 1 = Mode 1 dang dem thoi gian thuc
FLAG_SW_RUN  BIT 20H.3          ; 1 = Mode 2 dang dem xuoi
FLAG_CD_RUN  BIT 20H.4          ; 1 = Mode 3 dang dem nguoc
FLAG_CD_ALM  BIT 20H.5          ; 1 = Mode 3 het gio (nhap nhay 00:00)
FLAG_BLINK   BIT 20H.6          ; 0 = Pha sang, 1 = Pha tat (nhap nhay ~2Hz)
CUR_MODE     EQU 30H            ; 0 = Mode 1, 1 = Mode 2, 2 = Mode 3
SCAN_IDX     EQU 31H            ; Vi tri LED dang quet (0..3)
BLINK_CNT    EQU 32H            ; Bo dem nhap nhay (50 * 5ms = 250ms)
; Bo dem ma 7 doan ra LED (tu phai sang trai: P3.0 -> P3.3)
DISP_D4      EQU 34H            ; LED 4 - P3.0 (Don vi phai)
DISP_D3      EQU 35H            ; LED 3 - P3.1 (Chuc phai)
DISP_D2      EQU 36H            ; LED 2 - P3.2 (Don vi trai + DP)
DISP_D1      EQU 37H            ; LED 1 - P3.3 (Chuc trai)
DISP_LEFT    EQU 38H            ; Gia tri tam 2 so ben trai (0..59)
DISP_RIGHT   EQU 39H            ; Gia tri tam 2 so ben phai (0..59)
; Bien Mode 1: Dong ho thoi gian thuc (HH:MM, 00:00 - 23:59)
CLK_TICK     EQU 3AH            ; Dem ngat 5ms (0..199 = 1 giay)
CLK_SEC      EQU 3BH            ; Giay ngam (0..59)
CLK_MIN      EQU 3CH            ; Phut (0..59)
CLK_HR       EQU 3DH            ; Gio (0..23)
; Bien Mode 2: Dem xuoi (MM:SS, 00:00 - 59:59)
SW_TICK      EQU 3EH            ; Dem ngat 5ms (0..199 = 1 giay)
SW_SEC       EQU 3FH            ; Giay (0..59)
SW_MIN       EQU 40H            ; Phut (0..59)
; Bien Mode 3: Dem nguoc (MM:SS, 00:00 - 59:59)
CD_TICK      EQU 41H            ; Dem ngat 5ms (0..199 = 1 giay)
CD_SEC       EQU 42H            ; Giay hien tai (0..59)
CD_MIN       EQU 43H            ; Phut hien tai (0..59)
CD_SET_SEC   EQU 44H            ; Giay da cai dat (0..59)
CD_SET_MIN   EQU 45H            ; Phut da cai dat (0..59)
; ===================================================================
; CHUONG TRINH CHINH
; ===================================================================
        ORG 0030H
MAIN:
        MOV SP, #60H
        MOV P1, #0FFH           ; Cau hinh Port 1 doc 4 nut bam
        MOV P2, #00H            ; Tat het cac doan LED
        ORL P3, #0FH            ; Tat het 4 LED (P3.0..P3.3 = 1)
        ; Khoi tao bien he thong
        MOV CUR_MODE, #0        ; Bat dau o Mode 1 (Dong ho thoi gian thuc)
        MOV SCAN_IDX, #0
        MOV BLINK_CNT, #0
        MOV DISP_D4, #00H
        MOV DISP_D3, #00H
        MOV DISP_D2, #00H
        MOV DISP_D1, #00H
        ; Khoi tao Mode 1: 00:00 va tu dong chay
        MOV CLK_TICK, #0
        MOV CLK_SEC, #0
        MOV CLK_MIN, #0
        MOV CLK_HR, #0
        ; Khoi tao Mode 2: 00:00, dung
        MOV SW_TICK, #0
        MOV SW_SEC, #0
        MOV SW_MIN, #0
        ; Khoi tao Mode 3: 00:00, dung
        MOV CD_TICK, #0
        MOV CD_SEC, #0
        MOV CD_MIN, #0
        MOV CD_SET_SEC, #0
        MOV CD_SET_MIN, #0
        ; Khoi tao cac co trang thai
        CLR FLAG_EDIT
        CLR FLAG_FIELD
        SETB FLAG_CLK_RUN       ; Mode 1 chay ngay khi bat nguon
        CLR FLAG_SW_RUN
        CLR FLAG_CD_RUN
        CLR FLAG_CD_ALM
        CLR FLAG_BLINK
        ; Nap du lieu hien thi lan dau truoc khi bat ngat quet LED
        LCALL PREPARE_DISP
        ; Cai dat Timer 0 Mode 1 - Ngat 5ms (Thach anh 12MHz)
        MOV TMOD, #01H
        MOV TH0, #0ECH
        MOV TL0, #078H
        SETB ET0
        SETB EA
        SETB TR0
MAIN_LOOP:
        LCALL PREPARE_DISP
        LCALL CHECK_BUTTONS
        SJMP MAIN_LOOP
; ===================================================================
; KIEM TRA 4 NUT BAM (P1.0=START, P1.1=ADJUST, P1.2=RESET, P1.3=MODE)
; ===================================================================
CHECK_BUTTONS:
        ; --- 1. Nut START (P1.0) ---
        JB P1.0, CHK_ADJ
        LCALL DELAY_20MS
        JB P1.0, CHK_ADJ
        LCALL HANDLE_START
WAIT_P10:
        LCALL PREPARE_DISP
        JNB P1.0, WAIT_P10
        LCALL DELAY_20MS
        ; --- 2. Nut ADJUST (P1.1) ---
CHK_ADJ:
        JB P1.1, CHK_RST
        LCALL DELAY_20MS
        JB P1.1, CHK_RST
        LCALL HANDLE_ADJUST
WAIT_P11:
        LCALL PREPARE_DISP
        JNB P1.1, WAIT_P11
        LCALL DELAY_20MS
        ; --- 3. Nut RESET (P1.2) ---
CHK_RST:
        JB P1.2, CHK_MOD
        LCALL DELAY_20MS
        JB P1.2, CHK_MOD
        LCALL HANDLE_RESET
WAIT_P12:
        LCALL PREPARE_DISP
        JNB P1.2, WAIT_P12
        LCALL DELAY_20MS
        ; --- 4. Nut MODE (P1.3) ---
CHK_MOD:
        JB P1.3, END_CHK_BTN
        LCALL DELAY_20MS
        JB P1.3, END_CHK_BTN
        LCALL HANDLE_MODE
WAIT_P13:
        LCALL PREPARE_DISP
        JNB P1.3, WAIT_P13
        LCALL DELAY_20MS
END_CHK_BTN:
        RET
; ===================================================================
; XU LY NUT START (P1.0)
; ===================================================================
HANDLE_START:
        MOV A, CUR_MODE
        CJNE A, #0, START_CHK_M2
        ; --- Mode 1: Chi tac dung (+1) khi dang Edit ---
        JNB FLAG_EDIT, START_RET
        JB FLAG_FIELD, START_M1_HR
        ; Chinh MM (+1, 00..59)
        INC CLK_MIN
        MOV A, CLK_MIN
        CJNE A, #60, START_BLINK_ON
        MOV CLK_MIN, #0
        SJMP START_BLINK_ON
START_M1_HR:
        ; Chinh HH (+1, 00..23)
        INC CLK_HR
        MOV A, CLK_HR
        CJNE A, #24, START_BLINK_ON
        MOV CLK_HR, #0
        SJMP START_BLINK_ON
START_CHK_M2:
        CJNE A, #1, START_M3
        ; --- Mode 2: Dao trang thai Chay / Tam dung ---
        CPL FLAG_SW_RUN
        RET
START_M3:
        ; --- Mode 3 ---
        JB FLAG_EDIT, START_M3_EDIT
        ; Non-edit: neu dang bao het gio thi bo qua
        JB FLAG_CD_ALM, START_RET
        ; Neu dang chay -> Tam dung
        JNB FLAG_CD_RUN, START_M3_TRYRUN
        CLR FLAG_CD_RUN
        RET
START_M3_TRYRUN:
        ; Chi cho chay neu thoi gian > 00:00
        MOV A, CD_SEC
        ORL A, CD_MIN
        JZ START_RET
        SETB FLAG_CD_RUN
        RET
START_M3_EDIT:
        JB FLAG_FIELD, START_M3_MIN
        ; Chinh SS (+1, 00..59)
        INC CD_SEC
        MOV A, CD_SEC
        CJNE A, #60, START_BLINK_ON
        MOV CD_SEC, #0
        SJMP START_BLINK_ON
START_M3_MIN:
        ; Chinh MM (+1, 00..59)
        INC CD_MIN
        MOV A, CD_MIN
        CJNE A, #60, START_BLINK_ON
        MOV CD_MIN, #0
START_BLINK_ON:
        ; Giu so vua chinh sang ro ngay lap tuc
        MOV BLINK_CNT, #0
        CLR FLAG_BLINK
START_RET:
        RET
; ===================================================================
; XU LY NUT ADJUST (P1.1)
; ===================================================================
HANDLE_ADJUST:
        MOV A, CUR_MODE
        CJNE A, #0, ADJ_CHK_M3
        ; --- Mode 1: Dao Edit <-> Non-edit ---
        JB FLAG_EDIT, ADJ_M1_EXIT
        ; Vao Edit: tam dung dong ho thuc, nhap nhay MM truoc
        CLR FLAG_CLK_RUN
        SETB FLAG_EDIT
        CLR FLAG_FIELD          ; 0 = Chinh MM
        MOV BLINK_CNT, #0
        SETB FLAG_BLINK         ; Nhay tat ngay de bao hieu vao Edit
        RET
ADJ_M1_EXIT:
        ; Thoat Edit: reset giay ngam ve 0 va chay lai dong ho thuc
        MOV CLK_TICK, #0
        MOV CLK_SEC, #0
        CLR FLAG_EDIT
        CLR FLAG_FIELD
        SETB FLAG_CLK_RUN
        RET
ADJ_CHK_M3:
        CJNE A, #2, ADJ_RET     ; Mode 2: ADJUST khong co chuc nang
        ; --- Mode 3: Dao Edit <-> Non-edit ---
        JB FLAG_EDIT, ADJ_M3_EXIT
        ; Neu dang bao het gio 00:00 -> phai bam RESET, khong vao Edit
        JB FLAG_CD_ALM, ADJ_RET
        ; Vao Edit: dung dem, nap lai gio da set ban dau, nhap nhay SS truoc
        CLR FLAG_CD_RUN
        MOV CD_TICK, #0
        MOV CD_MIN, CD_SET_MIN
        MOV CD_SEC, CD_SET_SEC
        SETB FLAG_EDIT
        CLR FLAG_FIELD          ; 0 = Chinh SS
        MOV BLINK_CNT, #0
        SETB FLAG_BLINK         ; Nhay tat ngay de bao hieu vao Edit
        RET
ADJ_M3_EXIT:
        ; Thoat Edit: luu thoi gian da set, chua chay ngay (cho bam START)
        MOV CD_SET_MIN, CD_MIN
        MOV CD_SET_SEC, CD_SEC
        MOV CD_TICK, #0
        CLR FLAG_CD_RUN
        CLR FLAG_CD_ALM
        CLR FLAG_EDIT
        CLR FLAG_FIELD
ADJ_RET:
        RET
; ===================================================================
; XU LY NUT RESET (P1.2)
; ===================================================================
HANDLE_RESET:
        MOV A, CUR_MODE
        CJNE A, #0, RST_CHK_M2
        ; --- Mode 1: Chi tac dung (-1) khi dang Edit ---
        JNB FLAG_EDIT, RST_RET
        JB FLAG_FIELD, RST_M1_HR
        ; Chinh MM (-1, 00 -> 59)
        MOV A, CLK_MIN
        JNZ RST_M1_MIN_DEC
        MOV CLK_MIN, #59
        SJMP RST_BLINK_ON
RST_M1_MIN_DEC:
        DEC CLK_MIN
        SJMP RST_BLINK_ON
RST_M1_HR:
        ; Chinh HH (-1, 00 -> 23)
        MOV A, CLK_HR
        JNZ RST_M1_HR_DEC
        MOV CLK_HR, #23
        SJMP RST_BLINK_ON
RST_M1_HR_DEC:
        DEC CLK_HR
        SJMP RST_BLINK_ON
RST_CHK_M2:
        CJNE A, #1, RST_M3
        ; --- Mode 2: Ve 00:00 va ngung dem ---
        CLR FLAG_SW_RUN
        MOV SW_TICK, #0
        MOV SW_SEC, #0
        MOV SW_MIN, #0
        RET
RST_M3:
        ; --- Mode 3 ---
        JB FLAG_EDIT, RST_M3_EDIT
        ; Non-edit (ke ca khi dang bao het gio 00:00):
        ; Dung dem, tat bao het gio va nap lai thoi gian da set
        CLR FLAG_CD_RUN
        CLR FLAG_CD_ALM
        MOV CD_TICK, #0
        MOV CD_MIN, CD_SET_MIN
        MOV CD_SEC, CD_SET_SEC
        RET
RST_M3_EDIT:
        ; Edit: chi dua phan dang nhap nhay ve 00
        JB FLAG_FIELD, RST_M3_ZERO_MIN
        MOV CD_SEC, #0
        SJMP RST_BLINK_ON
RST_M3_ZERO_MIN:
        MOV CD_MIN, #0
RST_BLINK_ON:
        MOV BLINK_CNT, #0
        CLR FLAG_BLINK
RST_RET:
        RET
; ===================================================================
; XU LY NUT MODE (P1.3)
; ===================================================================
HANDLE_MODE:
        ; Neu dang o trang thai Edit (Mode 1 hoac Mode 3):
        ; chuyen doi qua lai giua cap phai (MM/SS) va cap trai (HH/MM)
        JNB FLAG_EDIT, MODE_SWITCH
        CPL FLAG_FIELD
        MOV BLINK_CNT, #0
        SETB FLAG_BLINK         ; Nhay tat ngay de nhan biet da doi vi tri
        RET
MODE_SWITCH:
        ; Dang o Non-edit: chuyen vong Mode 1 (0) -> Mode 2 (1) -> Mode 3 (2) -> Mode 1 (0)
        ; Cac bo dem dang chay se tiep tuc chay ngam
        INC CUR_MODE
        MOV A, CUR_MODE
        CJNE A, #3, MODE_RET
        MOV CUR_MODE, #0
MODE_RET:
        RET
; ===================================================================
; GIAI MA HIEN THI RA RAM 34H - 37H (CO XU LY NHAP NHAY)
; ===================================================================
PREPARE_DISP:
        ; Doc nhanh gia tri 2 cap so theo Mode hien tai (tranh lech khi ngat)
        CLR ET0
        MOV A, CUR_MODE
        CJNE A, #0, DISP_CHK_M2
        MOV DISP_LEFT, CLK_HR
        MOV DISP_RIGHT, CLK_MIN
        SJMP DISP_READ_DONE
DISP_CHK_M2:
        CJNE A, #1, DISP_LOAD_M3
        MOV DISP_LEFT, SW_MIN
        MOV DISP_RIGHT, SW_SEC
        SJMP DISP_READ_DONE
DISP_LOAD_M3:
        MOV DISP_LEFT, CD_MIN
        MOV DISP_RIGHT, CD_SEC
DISP_READ_DONE:
        SETB ET0
        ; --- Giai ma cap phai (DISP_RIGHT -> R2=D4, R3=D3) ---
        MOV A, DISP_RIGHT
        MOV B, #10
        DIV AB                  ; A = Chuc, B = Don vi
        MOV R3, A               ; Luu tam hang chuc
        MOV A, B
        LCALL GET_7SEG
        MOV R2, A               ; R2 = Ma LED 4 (P3.0)
        MOV A, R3
        LCALL GET_7SEG
        MOV R3, A               ; R3 = Ma LED 3 (P3.1)
        ; --- Giai ma cap trai (DISP_LEFT -> R4=D2+DP, R5=D1) ---
        MOV A, DISP_LEFT
        MOV B, #10
        DIV AB                  ; A = Chuc, B = Don vi
        MOV R5, A               ; Luu tam hang chuc
        MOV A, B
        LCALL GET_7SEG
        ORL A, #80H             ; Bat dau cham (.) co dinh o LED 2
        MOV R4, A               ; R4 = Ma LED 2 (P3.2)
        MOV A, R5
        LCALL GET_7SEG
        MOV R5, A               ; R5 = Ma LED 1 (P3.3)
        ; --- Xu ly nhap nhay khi dang o pha tat (FLAG_BLINK = 1) ---
        JNB FLAG_BLINK, DISP_COMMIT
        ; 1. Nhap nhay bao het gio Mode 3 (nhap nhay ca 4 so 00:00)
        MOV A, CUR_MODE
        CJNE A, #2, DISP_CHK_EDIT
        JNB FLAG_CD_ALM, DISP_CHK_EDIT
        MOV R2, #00H
        MOV R3, #00H
        MOV R4, #80H            ; Giu dau cham (.) co dinh; doi thanh #00H neu muon tat ca dau cham
        MOV R5, #00H
        SJMP DISP_COMMIT
        ; 2. Nhap nhay trong che do Edit (Mode 1 hoac Mode 3)
DISP_CHK_EDIT:
        JNB FLAG_EDIT, DISP_COMMIT
        JB FLAG_FIELD, DISP_BLANK_LEFT
        ; Dang chinh cap phai (MM o Mode 1, SS o Mode 3) -> tat LED 3, 4
        MOV R2, #00H
        MOV R3, #00H
        SJMP DISP_COMMIT
DISP_BLANK_LEFT:
        ; Dang chinh cap trai (HH o Mode 1, MM o Mode 3) -> tat LED 1, 2 (giu dau cham .)
        MOV R4, #80H
        MOV R5, #00H
DISP_COMMIT:
        ; Cap nhat dong bo bo dem 4 LED (34H - 37H)
        CLR ET0
        MOV DISP_D4, R2
        MOV DISP_D3, R3
        MOV DISP_D2, R4
        MOV DISP_D1, R5
        SETB ET0
        RET
GET_7SEG:
        MOV DPTR, #SEG_TABLE
        MOVC A, @A+DPTR
        RET
; Bang ma 7 doan Cathode Chung (Muc 1 = Sang)
SEG_TABLE:
        DB 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH, 6FH
; ===================================================================
; NGAT TIMER 0 (5ms): QUET LED + NHAP NHAY + DEM NGAM CA 3 MODE
; ===================================================================
T0_ISR:
        CLR TR0
        MOV TH0, #0ECH
        MOV TL0, #078H
        SETB TR0
        PUSH ACC
        PUSH PSW
        PUSH 00H                ; Bao toan thanh ghi R0 (Bank 0)
        ; --- 1. Quet 4 LED 7 doan ---
        ORL P3, #0FH            ; Tat het LED cu (chong bong ma)
        MOV A, #34H
        ADD A, SCAN_IDX
        MOV R0, A
        MOV P2, @R0
        MOV A, SCAN_IDX
        CJNE A, #0, SCAN_2
        ANL P3, #0FEH           ; P3.0 = 0 -> LED 4 (ngoai cung phai)
        SJMP NEXT_DIGIT
SCAN_2: CJNE A, #1, SCAN_3
        ANL P3, #0FDH           ; P3.1 = 0 -> LED 3
        SJMP NEXT_DIGIT
SCAN_3: CJNE A, #2, SCAN_4
        ANL P3, #0FBH           ; P3.2 = 0 -> LED 2
        SJMP NEXT_DIGIT
SCAN_4: ANL P3, #0F7H           ; P3.3 = 0 -> LED 1 (ngoai cung trai)
NEXT_DIGIT:
        INC SCAN_IDX
        MOV A, SCAN_IDX
        CJNE A, #4, ISR_BLINK
        MOV SCAN_IDX, #0
        ; --- 2. Tao xung nhap nhay 2Hz (250ms sang / 250ms tat) ---
ISR_BLINK:
        INC BLINK_CNT
        MOV A, BLINK_CNT
        CJNE A, #50, ISR_CLK
        MOV BLINK_CNT, #0
        CPL FLAG_BLINK
        ; --- 3. Dem thoi gian thuc - Mode 1 (24h: 00:00 - 23:59) ---
ISR_CLK:
        JNB FLAG_CLK_RUN, ISR_SW
        INC CLK_TICK
        MOV A, CLK_TICK
        CJNE A, #200, ISR_SW    ; 200 * 5ms = 1 giay
        MOV CLK_TICK, #0
        INC CLK_SEC
        MOV A, CLK_SEC
        CJNE A, #60, ISR_SW
        MOV CLK_SEC, #0
        INC CLK_MIN
        MOV A, CLK_MIN
        CJNE A, #60, ISR_SW
        MOV CLK_MIN, #0
        INC CLK_HR
        MOV A, CLK_HR
        CJNE A, #24, ISR_SW
        MOV CLK_HR, #0
        ; --- 4. Dem xuoi - Mode 2 (MM:SS: 00:00 - 59:59) ---
ISR_SW:
        JNB FLAG_SW_RUN, ISR_CD
        INC SW_TICK
        MOV A, SW_TICK
        CJNE A, #200, ISR_CD    ; 200 * 5ms = 1 giay
        MOV SW_TICK, #0
        INC SW_SEC
        MOV A, SW_SEC
        CJNE A, #60, ISR_CD
        MOV SW_SEC, #0
        INC SW_MIN
        MOV A, SW_MIN
        CJNE A, #60, ISR_CD
        MOV SW_MIN, #0
        ; --- 5. Dem nguoc - Mode 3 (MM:SS: 00:00 - 59:59) ---
ISR_CD:
        JNB FLAG_CD_RUN, EXIT_ISR
        INC CD_TICK
        MOV A, CD_TICK
        CJNE A, #200, EXIT_ISR  ; 200 * 5ms = 1 giay
        MOV CD_TICK, #0
        ; An toan: neu da la 00:00 thi chi dung lai
        MOV A, CD_SEC
        ORL A, CD_MIN
        JZ CD_STOP_ZERO
        ; Giam 1 giay
        MOV A, CD_SEC
        JNZ CD_DEC_SEC
        MOV CD_SEC, #59
        DEC CD_MIN
        SJMP EXIT_ISR
CD_DEC_SEC:
        DEC CD_SEC
        MOV A, CD_SEC
        ORL A, CD_MIN
        JNZ EXIT_ISR
        ; Vua cham 00:00 -> Dung dem & bat nhap nhay bao het gio
        CLR FLAG_CD_RUN
        SETB FLAG_CD_ALM
        MOV BLINK_CNT, #0
        CLR FLAG_BLINK
        SJMP EXIT_ISR
CD_STOP_ZERO:
        CLR FLAG_CD_RUN
EXIT_ISR:
        POP 00H
        POP PSW
        POP ACC
        RETI
; ===================================================================
; TRE CHONG DOI NUT BAM ~20ms (THACH ANH 12MHz)
; ===================================================================
DELAY_20MS:
        MOV R6, #40
D1:     MOV R7, #250
D2:     DJNZ R7, D2
        DJNZ R6, D1
        RET
        END
