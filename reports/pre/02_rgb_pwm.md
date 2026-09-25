# 실험 전 레포트: RGB LED PWM 제어

작성일 2026-09-25.

## 1. 동작 원리와 핵심 파라미터 계산

### 동작 원리
단일 50 MHz 메인 클록 도메인에서 3개의 독립된 푸시버튼(`button_r`, `button_g`, `button_b`)을 사용하여 빨강(R), 초록(G), 파랑(B) 3채널의 PWM 듀티비를 개별적으로 제어한다. 각 채널은 동일한 스위칭 주파수(1 kHz)를 공유하면서 각자의 레벨(0%~100%, 10단계)에 따라 독립된 High 펄스 폭을 생성한다. 생성된 3채널 PWM 신호는 보드의 4개 RGB LED에 병렬 공급되어 가산 혼합(Additive Color Mixing) 원리에 따라 다양한 색상과 밝기를 표출한다. 외부 비동기 스위치 입력에는 2단 동기화기와 20 ms 디바운스 로직을 각각 적용하여 채터링 현상 없는 1클록 폭의 제어 펄스를 보장한다.

### 핵심 파라미터 계산
1. **공통 PWM 주기 카운트 (`PERIOD_CYCLES`)**:
   - 입력 주 클록 주파수 $f_{\mathrm{clk}} = 50\text{ MHz} = 50,000,000\text{ Hz}$
   - PWM 목표 스위칭 주파수 $f_{\mathrm{pwm}} = 1\text{ kHz} = 1,000\text{ Hz}$
   - 1주기당 필요한 클록 수:
     $$\text{PERIOD\_CYCLES} = \frac{f_{\mathrm{clk}}}{f_{\mathrm{pwm}}} = \frac{50,000,000}{1,000} = 50,000\text{ cycles}$$
   - 카운터 레지스터 비트 폭:
     $$\text{COUNT\_WIDTH} = \lceil\log_2(50,000)\rceil = 16\text{ bits}$$

2. **버튼 디바운스 안정화 카운트 (`DEBOUNCE_CYCLES`)**:
   - 스위치 안정화 기준 시간 $T_{\mathrm{stable}} = 20\text{ ms} = 0.02\text{ s}$
   - 필요 클록 주기 수:
     $$\text{DEBOUNCE\_CYCLES} = 50,000,000 \times 0.02 = 1,000,000\text{ cycles}$$
   - 디바운스 카운터 비트 폭:
     $$\text{COUNT\_WIDTH} = \lceil\log_2(1,000,000)\rceil = 20\text{ bits}$$

3. **채널별 임계값 (`threshold`) 및 듀티비 계산**:
   - 10단계(`LEVELS = 10`) 기준: $\text{threshold} = \frac{\text{PERIOD\_CYCLES} \times \text{level}}{10} = 5,000 \times \text{level}$
   - level=0: threshold=0 (High 클록 0개, 듀티 0%, 해당 색상 완전 소등)
   - level=2: threshold=10,000 (High 클록 10,000개, 듀티 20%)
   - level=5: threshold=25,000 (High 클록 25,000개, 듀티 50%)
   - level=8: threshold=40,000 (High 클록 40,000개, 듀티 80%)
   - level=10: threshold=50,000 (High 클록 50,000개, 듀티 100%, 최대 밝기)

---

## 2. 파일 구성과 역할

| 경로 | 파일명 | 역할 및 설명 |
|---|---|---|
| `src/` | `button_onepulse.v` | 2단 동기화(`ASYNC_REG`)로 메타스테이블을 방지하고 20 ms 디바운스 후 1클록 펄스를 출력 |
| `src/` | `pwm_channel.v` | 공통 카운터 기반으로 각 채널의 level에 따른 듀티비 사각파를 생성 |
| `src/` | `lab3_rgb_pwm.v` | 설계 최상위(Design Top). 3개 버튼 입력 처리, 독립 level 제어 및 4개 RGB LED 12핀 분배 |
| `sim/` | `tb_rgb_pwm.sv` | 시뮬레이션 최상위(Simulation Top). 축소된 파라미터로 다채널 동시 계측 및 독립 제어 자기 검증 |
| `constraints/` | `lab3_rgb_pwm.xdc` | 50 MHz 클록(B6), 리셋(K4), 3개 버튼(N8, N4, N1), RGB LED 12핀 매핑 및 20 ns 타이밍 제약 선언 |
| 루트 | `simulation.json` | VS Code Icarus Verilog 빌드를 위한 소스 목록 및 최상위 모듈 설정 |

---

## 3. 테스트벤치 자극과 기대 결과

시뮬레이션 환경에서는 실행 시간 단축을 위해 `CLK_HZ=1000`, `PWM_HZ=100`, `LEVELS=10`, `DEBOUNCE_CYCLES=2`로 축소 인가하며, 1주기(10클록) 동안 R, G, B 각 채널의 High 클록 수(`hr`, `hg`, `hb`)를 동시 계측한다.

| 검사 순서 | 인가 자극 | 채널별 설정 level (R, G, B) | 1주기 내 High 클록 기대값 (hr, hg, hb) | 판정 기준 및 검증 의미 |
|:---:|---|:---:|:---:|---|
| Check 1 | R 2회, G 5회, B 8회 누름 | R=2, G=5, B=8 | hr=2, hg=5, hb=8 | 세 채널의 독립 듀티(20%, 50%, 80%) 동시 출력 검증 |
| Check 2 | R 버튼만 추가 1회 누름 | R=3, G=5, B=8 | hr=3, hg=5, hb=8 | G, B 채널에 간섭 없이 R 채널만 30%로 단독 증가하는지 검증 |

---

## 4. 시뮬레이션 결과 및 수정 실험

### 정상 시뮬레이션 확인
- **[종료 로그](../../evidence/02/vscode/simulation.txt)**: `LAB3_RGB_PWM_PASS checks=2`, 종료 시각 `4431000 ps (4431 ns)`
- **[파형 분석](../../evidence/02/vscode/wave.png)**:
  - `measure(2, 5, 8)` 구간: 1주기 10클록 동안 `led_r`은 2클록, `led_g`는 5클록, `led_b`는 8클록 동안 High를 유지하여 세 색상의 펄스 폭이 독립적으로 제어됨을 확인.
  - `measure(3, 5, 8)` 구간: R 버튼 1회 입력 후 `led_r`의 High 폭만 2클록에서 3클록으로 증가하고, `led_g`와 `led_b`는 이전 듀티(5클록, 8클록)를 완벽히 유지함을 확인.

### 수정 실험 (오류 주입 및 복구)
`lab3_rgb_pwm.v`에서 리셋 시 초기 듀티를 0이 아닌 임의의 값(예: `level_r <= 4'd1;`)으로 수정하여 테스트벤치 검출 신뢰성을 점검한다.

| 실험 단계 | 설정 내용 | 기대 동작 | 실제 실행 결과 | 비고 |
|---|---|---|---|---|
| 정상 실행 | 리셋 시 `level_r=0, level_g=0, level_b=0` | R 2회 누름 후 hr=2 | `LAB3_RGB_PWM_PASS checks=2` (4431 ns 종료) | 정상 통과 |
| 고장 주입 | 리셋 시 `level_r <= 4'd1;` 로 변경 | R 2회 누름 후 level_r=3이 되어 hr=3 출력 | `rgb high=3,5,8 expected=2,5,8` 불일치로 `$fatal` 중단 | 테스트벤치 검출 확인 |
| 원복 복구 | 리셋 시 `level_r <= 4'd0;` 복원 | R 2회 누름 후 hr=2 복구 | `LAB3_RGB_PWM_PASS checks=2` 복구 | 정상 확인 |

---

## 5. 보드 실험 계획 및 관찰 항목

### 하드웨어 환경 및 핀 매핑
- **타깃 FPGA**: Spartan-7 `xc7s75fgga484-1`
- **클록 및 리셋**: 온보드 50 MHz 오실레이터 (B6 핀), 리셋 푸시버튼 K4
- **입력 버튼**: N8 (Red 제어), N4 (Green 제어), N1 (Blue 제어)
- **출력 핀**: RGB LED 4개 (총 12핀, `led_r[3:0]`: T2/U1/P2/R3, `led_g[3:0]`: U5/V1/R7/T6, `led_b[3:0]`: U3/W2/R5/T3)

### 보드 관찰 절차
1. 비트스트림(`lab3_rgb_pwm.bit`) 다운로드 후 K4 버튼으로 리셋 초기화를 수행하여 4개의 RGB LED가 모두 소등되는지 확인한다.
2. N8 버튼만 눌러 Red 밝기만 10단계로 변하고 Green, Blue는 꺼져 있는지 확인한다.
3. N4 버튼(Green)과 N1 버튼(Blue)을 각각 독립 조작하여 각 채널이 서로 간섭 없이 개별 밝기가 변하는지 확인한다.
4. R, G, B 세 버튼을 조합하여 보라색(R+B), 노란색(R+G), 청록색(G+B), 흰색(R+G+B) 등 가산 혼합 색상이 정상 표출되는지 육안으로 확인하고 사진 및 영상으로 기록한다.