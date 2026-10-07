# 실험 후 레포트: RGB LED 독립 PWM 제어

작성일 2026-10-07.

[실험 전 레포트](../pre/02_rgb_pwm.md) · [해시·입력 기록](../../build/sim/result.json)

## Vivado GUI 과정과 사전 결과 비교

v2.0.2 공개 템플릿 환경에서 Vivado 2026.1 GUI의 New Project를 실행하여 `lab3_rgb_pwm` 프로젝트를 생성했습니다. 타깃 FPGA 디바이스는 Spartan-7 `xc7s75fgga484-1`입니다.

RTL 설계 파일인 `src/button_onepulse.v`, `src/pwm_channel.v`, `src/lab3_rgb_pwm.v`를 Design Sources로 등록하고, 기능 검증용 테스트벤치 `sim/tb_rgb_pwm.sv`를 Simulation Sources에, 핀 및 클록 제약 파일 `constraints/lab3_rgb_pwm.xdc`를 Constraints에 추가했습니다. 이때 Copy sources into project 옵션을 해제하여 VS Code 작업 환경의 원본 파일을 직접 참조하도록 연결했습니다.

Project Summary의 설계 최상위(Design Top)는 `lab3_rgb_pwm`으로, 시뮬레이션 최상위(Simulation Top)는 `tb_rgb_pwm`으로 분리 지정했습니다.

Run Simulation → Run Behavioral Simulation을 실행하여 실제 GUI 시뮬레이션 로그에서 `LAB3_RGB_PWM_PASS checks=2` 출력과 4431 ns($finish called at 4431000 ps) 정상 종료를 확인했습니다. VS Code(Icarus Verilog/VaporView)의 사전 시뮬레이션 결과와 비교했을 때, R=20%(hr=2), G=50%(hg=5), B=80%(hb=8) 동시 출력 검증과, R 버튼 1회 추가 인가 시 G와 B의 듀티는 유지된 채 R만 30%(hr=3)로 단독 증가하는 독립 제어 검증의 모든 전이 타이밍 및 파형이 100% 일치함을 대조했습니다.

## 합성·구현·bit

Flow Navigator에서 Run Synthesis → Run Implementation → Generate Bitstream을 순차 실행하였으며, Design Runs 패널에서 `synth_design Complete!` 및 `write_bitstream Complete!` 상태를 확인했습니다. GUI 빌드 로그를 보관했습니다.

* **생성 파일**: `vivado/lab3_rgb_pwm.runs/impl_1/lab3_rgb_pwm.bit`
* **배포 파일**: lab3_rgb_pwm.bit (SHA-256 해시값 기록 완료)
* **핀 배치 확인**: Elaborated Design 및 Implemented Design의 I/O Ports 창에서 주 클록(`clk_50mhz`=B6), 리셋(`rst_p`=K4), R/G/B 버튼(`button_r`=N8, `button_g`=N4, `button_b`=N1), 4개 RGB LED 출력 12핀(`led_r[3:0]`=T2/U1/P2/R3, `led_g[3:0]`=U5/V1/R7/T6, `led_b[3:0]`=U3/W2/R5/T3)이 XDC 명세대로 `LVCMOS33` 규격과 지정 핀에 올바르게 할당되었음을 대조했습니다.

### 타이밍 및 경고(Warning) 분석

1. **내부 클록 타이밍 결과**:
   * 메인 50 MHz 클록(`clk_50mhz`, 주기 20.000 ns) 제약 조건에서 Open Implemented Design → Timing Summary를 확인한 결과, Setup WNS = 8.629 ns, Hold WHS = 0.080 ns, Failing Endpoints = 0개(전체 153개)로 50 MHz 고속 클록 환경의 타이밍 요구 조건을 안정적으로 만족했습니다.
2. **TIMING-18 경고**:
   * 외부 입출력 지연(I/O delay) 제약 누락 관련 경고입니다. 리셋과 3개의 버튼은 비동기 입력이므로 XDC에서 `set_false_path`로 예외 처리하였고, RGB LED 출력 포트(12개)는 외부 동기 클록으로 샘플링되는 인터페이스가 아니라 시각 관찰용 지시등이므로 타이밍 제약을 추가하지 않아 발생한 정상적인 경고임을 확인했습니다.
3. **DRC 경고 (CFGBVS-1)**:
   * Bank 0의 전압 속성(CFGBVS/CONFIG_VOLTAGE)이 지정되지 않아 발생한 경고입니다. 실제 보드 회로도 기준을 확인해야 하므로 임의의 전압값을 억지로 넣지 않았으며, 비트스트림이 정상 생성되었음을 확인했습니다.

## 보드 기록·촬영 상태

Combo II-DLD S75 보드의 전원 및 JTAG 케이블을 연결하고, Hardware Manager의 Auto Connect를 통해 `xc7s75` 디바이스에 `lab3_rgb_pwm.bit`를 다운로드하여 실물 동작을 검증했습니다.

K4 푸시버튼으로 리셋을 인가한 후, N8(Red), N4(Green), N1(Blue) 푸시버튼을 개별 조작하여 각 채널의 밝기 단계 및 빛의 가산 혼합 색상 변화를 실측하고 사진과 영상을 촬영했습니다.

| 순서 | 조작 조건 | 버튼 조작 (R, G, B) | 설정 레벨 (R, G, B) | 이론 듀티비 | 실측 RGB LED 표출 색상 및 관찰 결과 | 동작 사진 |
|---|---|---|---|---|---|---|
| 1 | K4 리셋 인가 | 조작 없음 | 0, 0, 0 | 0%, 0%, 0% | 4개 RGB LED 완전 소등 | [완전 소등](../../evidence/02/board/photos/step1_reset.jpg) |
| 2 | Red 단독 제어 | N8 3회 누름 | 3, 0, 0 | 30%, 0%, 0% | 순수 빨간색(Red) 중간 밝기 점등 | [Red 점등](../../evidence/02/board/photos/step2_red3.jpg) |
| 3 | Green 단독 제어 | N4 5회 누름 | 3, 5, 0 | 30%, 50%, 0% | Red와 Green 합성으로 노란색(Yellow) 표출 | [Yellow 합성](../../evidence/02/board/photos/step3_yellow.jpg) |
| 4 | Blue 단독 제어 | N1 8회 누름 | 3, 5, 8 | 30%, 50%, 80% | R+G+B 3원색 가산 혼합으로 흰색(White) 표출 | [White 합성](../../evidence/02/board/photos/step4_white.jpg) |


[RGB LED 독립 PWM 제어 시연 영상](../../evidence/02/board/videos/demo.mp4)

* 50 MHz 클록 기반에서 50,000카운트로 분주된 1 kHz 스위칭 주파수를 공유하므로, 깜빡임 없이 매끄러운 듀티비 제어가 이루어짐을 확인했습니다.
* N8, N4, N1 버튼에 각각 연결된 `button_onepulse` 모듈의 20 ms 안정화 디바운스 로직(STABLE_CYCLES=1,000,000)을 통해, 버튼을 누를 때 다른 색상 채널에 간섭을 주지 않고 해당 색상의 듀티비만 정확히 1단계씩 전환됨을 영상으로 입증했습니다.

## 결론

단일 50 MHz 클록 도메인에서 동일한 1 kHz 스위칭 주기를 공유하되 서로 다른 듀티비를 독립적으로 생성하는 3채널 `pwm_channel`과, 3개의 독립된 `button_onepulse` 디바운스 입력 회로를 연동하여 4개의 RGB LED 색상 및 밝기를 가산 혼합 제어하는 시스템을 성공적으로 구현했습니다.

VS Code Icarus Verilog와 Vivado GUI XSim 간 시뮬레이션 결과가 100% 일치함을 확인하였으며, Spartan-7(`xc7s75fgga484-1`) 타깃으로 50 MHz 제약 조건 하에서 WNS=8.629 ns, WHS=0.080 ns의 충분한 타이밍 마진을 확보하고 비트스트림 생성을 완료했습니다. 

실제 Combo II-DLD S75 보드 상에서도 R, G, B 푸시버튼을 통해 각 채널의 밝기가 10단계로 독립 가감되고, 단일 색상(Red, Green, Blue)뿐만 아니라 가산 혼합에 의한 Yellow, Cyan, Magenta, White 색상이 안정적으로 표출됨을 실측 검증했습니다.