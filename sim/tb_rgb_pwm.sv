`timescale 1ns/1ps

module tb_rgb_pwm;
  reg clk_50mhz = 0, rst_p = 1, button_r = 0, button_g = 0, button_b = 0;
  wire [3:0] led_r, led_g, led_b;
  integer checks = 0, i, hr, hg, hb;

  // 50 MHz 클록 생성 (#10 = 20 ns 주기)
  always #10 clk_50mhz = ~clk_50mhz;

  // 시뮬레이션용 빠른 파라미터 축소 설정
  lab3_rgb_pwm #(
    .CLK_HZ(1000),
    .PWM_HZ(100),
    .LEVELS(10),
    .DEBOUNCE_CYCLES(2)
  ) dut (
    .clk_50mhz(clk_50mhz),
    .rst_p(rst_p),
    .button_r(button_r),
    .button_g(button_g),
    .button_b(button_b),
    .led_r(led_r),
    .led_g(led_g),
    .led_b(led_b)
  );

  // R, G, B 버튼 누름 자극 태스크
  task press_r;
    begin
      button_r = 1; repeat(6) @(posedge clk_50mhz);
      button_r = 0; repeat(6) @(posedge clk_50mhz);
    end
  endtask

  task press_g;
    begin
      button_g = 1; repeat(6) @(posedge clk_50mhz);
      button_g = 0; repeat(6) @(posedge clk_50mhz);
    end
  endtask

  task press_b;
    begin
      button_b = 1; repeat(6) @(posedge clk_50mhz);
      button_b = 0; repeat(6) @(posedge clk_50mhz);
    end
  endtask

  // 1주기(10클록) 동안 R, G, B High 클록 수를 동시 측정·비교하는 태스크
  task measure(input integer er, input integer eg, input integer eb);
    begin
      wait(dut.u_pwm_r.count == 0);
      hr = 0; hg = 0; hb = 0;
      for (i = 0; i < 10; i = i + 1) begin
        @(posedge clk_50mhz);
        #1;
        hr += led_r[0];
        hg += led_g[0];
        hb += led_b[0];
      end
      if (hr !== er || hg !== eg || hb !== eb)
        $fatal(1, "rgb high=%0d,%0d,%0d expected=%0d,%0d,%0d", hr, hg, hb, er, eg, eb);
      checks = checks + 1;
    end
  endtask

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_rgb_pwm);

    repeat(3) @(posedge clk_50mhz);
    rst_p = 0;

    // R 2회(20%), G 5회(50%), B 8회(80%) 누름 후 동시 측정 (Check 1)
    repeat(2) press_r();
    repeat(5) press_g();
    repeat(8) press_b();
    measure(2, 5, 8);

    // R 버튼만 1회 추가 누름 -> R만 30%로 증가, G/B 유지 검사 (Check 2)
    press_r();
    measure(3, 5, 8);

    $display("LAB3_RGB_PWM_PASS checks=%0d", checks);
    $finish;
  end

  initial begin
    #30000;
    $fatal(1, "timeout");
  end

endmodule