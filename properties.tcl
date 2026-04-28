## SP 01 Type: IFT
## Verification Level: IP
## Requirement: C cannot receive data from P which originates while the ACW is actively being reset.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP01_RECEIVE_GENERIC: assert iflow(`signal_from_P` when (ARESETN == 0) =/=> `signal_to_C`);
## Adaptation to HACK@DAC21: While Controller's reset is active, data or responses originating from trusted peripherals should not be able to propagate to the untrusted controller logic.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv 
assert -name SP01{ 
  aes0_wrapper_i.rdata
  when (~ariane_i.rst_ni)
  =/=> 
  ariane_i.axi_resp_i.r.data } 
## Jasper SPV readable 
check_spv -create \
 -name SP01 \
 -from aes0_wrapper_i.rdata \
 -to ariane_i.axi_resp_i.r.data \
 -to_precond {~ariane_i.rst_ni}
## Assertion covered and satisfied, need to set reset -none 

## SP 02 Type: IFT
## Verification Level: IP
## Requirement: C cannot send data to P which originates while the ACW is actively being reset.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP02_SEND_GENERIC: assert iflow(`signal_from_C` when (ARESETN == 0) =/=> `signal_to_P`);
## Adaptation to HACK@DAC21: While Controller's reset is active, data or requests originating from the untrusted controller logic should not be able to propagate to the trusted peripherals.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv 
assert -name SP02{ 
  ariane_i.axi_req_o.w.data
  when (~ariane_i.rst_ni)
  =/=> 
  aes0_wrapper_i.wdata } 
## Jasper SPV readable 
check_spv -create \
 -name SP02 \
 -from ariane_i.axi_req_o.w.data \
 -to aes0_wrapper_i.wdata \
 -to_precond {~ariane_i.rst_ni}
## Assertion covered and satisfied, need to set reset -none 

## SP 03 Type: Trace
## Verification Level: IP
## Requirement: C receives the default AXI signals while the ACW is actively being reset.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP03_DEFAULT_GENERIC: assert iflow(`signal_to_C`==`default_AXI_value` unless (ARESETN != 0));
## Adaptation to Hack@DAC21: When Controller is under reset, signals received from the AXI interface should remain at default/inactive values.
## Sample Module: Controller: ariane.sv 
assert -name SP03 {
  (~ariane_i.rst_ni) |-> (!ariane_i.axi_resp_i.r_valid)
}
## Assertion violated

## SP 04 Type: Trace
## Verification Level: IP
## Requirement: The ACW outputs the default AXI signals to P while the ACW is actively being reset.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP04_DEFAULT_GENERIC: assert iflow(`signal_to_P`==`default_AXI_value` unless (ARESETN != 0));
## Adaptation to Hack@DAC21: when Controller is under reset, signals delivered from the AXI interface into the peripheral logic should remain at default/inactive values
## Sample Module: Controller: ariane.sv, Peripheral: aes0_wrapper.sv
assert -name SP04 {
  (~ariane_i.rst_ni) |-> (!ariane_i.axi_req_o.aw_valid)
}
## Assertion covered and satisfied

## SP 05 Type: Trace
## Verification Level: IP
## Requirement: The configuration/anomaly registers are cleared and set to contain the default values while the ACW is actively being reset.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP05_DEFAULT_GENERIC: assert iflow(`reg`==`default_value`unless (ARESETN != 0 &&`acw_w/r_state` != 2’b00));
## Re-interpreted: During ACW reset, configuration/anomaly registers inside ACW must be cleared to default values. 
## Threrefore, this property does not directly apply to Hack@DAC21's AXI interconnect, becasue it requires both the condition and target signals to be inside the ACW. 
## Adapt this SP to Hack@DAC21: registers in P that are exposed via the AXI interface must be default when C is under reset. 
## To differentiate this modified SP05 with SP04, we expllicitly require the registers in P needs to be control/status registers, not read or write data registers. 
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv 
assert -name SP05 {
  (~ariane_i.rst_ni) |=> (~aes0_wrapper_i.en_acct && ~aes0_wrapper_i.we)
}
## Assertion covered and satisfied

## SP 06 Type: IFT
## Verification Level: Firmware
## Requirement: The TE can read from but not write to anomaly/configuration registers
## SP Specification Template: //# of Generic Signals to Replace = 3 SP06_RONLY_GENERIC: assert iflow(`signal_from_TE`when (S_AXI_CTRL_AWADDR ==`reg_addr`)=/=>`anomaly_reg`);
## Re-interpreted: In Aker's setup, TE is a design independent from ACW, C, Interconnect, or P. To adapt this property to Hack@DAC21, we consider signal_from_TE as signal/data from CPU,
## e.g. write data, write enable.  "when (S_AXI_CTRL_AWADDR ==`reg_addr`)" means the CPU is trying to write to anomaly registers. 
## Anomaly register is a register that stores security violations / flags, belongs to ACW in this context. 
## Therefore, this property does not directly apply to Hack@DAC21's AXI interconnect, because it requires target signals to be inside the ACW. 
## Adapt this SP to Hack@DAC21: Signals from C must not be able to modify error flags or status registers inside P.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv 
assert -name SP06{ 
  ariane_i.axi_req_o.w.data
  when (address == ct_valid_addr) 
  =/=> 
  aes0_wrapper_i.ct_valid} 
## Jasper SPV readable 
check_spv -create \
 -name SP06 \
 -from ariane_i.axi_req_o.w.data \
 -to aes0_wrapper_i.ct_valid \
## Assertion covered and satisfied, and by eyeballing the design we can see on the read side, ct_valid's address (11) is included in the case statement, while excluded on the write side.

## SP 07 Type: IFT
## Verification Level: IP
## Requirement: C cannot receive data from P which originates while the ACW is in reset mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP07_RECEIVE_GENERIC: assert iflow(`signal_from_P` when (`acw_w/r_state`== 2’b00) =/=> `signal_to_C`);
## To differentiate SP07 (reset mode) with SP01 (actively being reset), in SP01 we use CPU's reset signal (corresponding to ARESETN == 0), and in SP07 we use P's enable signal (originated from AXI)
## Adaptation to Hack@DAC21: If the interface enable signal to the peripheral is deasserted, data originating from the peripheral must not propagate to the controller.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv 
assert -name SP07{ 
  aes0_wrapper_i.rdata
  when (~aes0_wrapper_i.en)
  =/=> 
  ariane_i.axi_resp_i.r.data } 
## Jasper SPV readable 
check_spv -create \
 -name SP07 \
 -from aes0_wrapper_i.rdata \
 -to ariane_i.axi_resp_i.r.data \
 -to_precond {~aes0_wrapper_i.en}
## Assertion covered and satisfied

## SP 08 Type: IFT
## Verification Level: IP
## Requirement: C cannot send data to P which originates while the ACW is in reset mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP08_SEND_GENERIC: assert iflow(`signal_from_C` when (`acw_w/r_state`== 2’b00) =/=>`signal_to_P`);
## Similar as SP07 
## Adaptation to Hack@DAC21: If the interface enable signal to the peripheral is deasserted, data originating from the controller must not propagate to the periperal.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv 
assert -name SP08{ 
  ariane_i.axi_req_o.w.data
  when (~aes0_wrapper_i.en)
  =/=> 
  aes0_wrapper_i.wdata } 
## Jasper SPV readable 
check_spv -create \
 -name SP08 \
 -from ariane_i.axi_req_o.w.data \
 -to aes0_wrapper_i.wdata \
 -to_precond {~aes0_wrapper_i.en}
## Assertion covered and satisfied

## SP 09 Type: Trace 
## Verification Level: IP
## Requirement: C receives the default AXI signals while the ACW is in reset mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP09_DEFAULT_GENERIC: assert iflow(`signal_to_C`==`default_AXI_value`unless (`acw_w/r_state` != 2’b00));
## Since Hack@DAC’21 does not include an explicit ACW component, we reinterpret SP09 in terms of peripheral-driven inactivity. 
## Specifically, we use the enable signal en_acct as an indicator that the peripheral is inactive, and check that the controller observes only default AXI responses in this case.
## Adaptation to Hack@DAC21: When the interface enable signal is low, the controller should receive default/inactive AXI response values.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv
assert -name SP09 {
  (~aes0_wrapper_i.en_acct) |-> (!ariane_i.axi_resp_i.r_valid)
}
## Assertion violated

## SP 10 Type: Trace
## Verification Level: IP
## Requirement: The ACW outputs the default AXI signals to P while the ACW is in reset mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP10_DEFAULT_GENERIC: assert iflow( `signal_to_P` == `default_AXI_value` unless (`acw_w/r_state` != 2'b00) );
## Similar to the above, there's no ACW, so we choose the enable signal originated from AXI
## Adaptation to Hack@DAC21: When the interface enable signal is low, the peripheral should receive default/inactive AXI response values.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv
assert -name SP10 {
  (~aes0_wrapper_i.en_acct) |-> (!ariane_i.axi_req_o.aw_valid)
}
## Assertion violated

## SP 11 Type: IFT
## Verification Level: Firmware
## Requirement: The configuration/anomaly registers contain the default values until they are modified by the TE (config.) and/or ACW (illegal req. metadata tracking).
## SP Specification Template: //# of Generic Signals to Replace = 3 SP11_DEFAULT_GENERIC: assert iflow(`unauthorized_signal` when (`reg`==`default_value`)=/=>`reg`unless (`reg`==`default_value`));
## We catch a bug inside the template: it should be "unless (`reg`!=`default_value`)" rather than "unless (`reg`==`default_value`)"
## Re-interpret: Similar to SP06, there's no ACW in Hack@DAC21. Therefore, we use status flag in P to represent configuration/anomaly registers.
## Adaptation to Hack@DAC21: Signals from C must not be able to modify default-valued status/configuration registers inside P, unless the register no longer holds the default value. 
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv
check_spv -create \
  -name SP11 \
  -from ariane_i.axi_req_o.w.data \
  -to aes0_wrapper_i.ct_valid \
  -to_precond { aes0_wrapper_i.ct_valid == 1'b0 }
## Assertion covered and satisfied

## SP 12 Type: IFT
## Verification Level: IP
## Requirement: C cannot receive data associated with an illegal address from P which originates while the ACW is in supervising mode.
## SP Specification Template: //# of Generic Signals to Replace = 4 SP12_RECEIVE_GENERIC: assert iflow(`signal_from_P` when (`acw_w/r_state`== 2'b01) && (`AR/AW_ADDR_VALID_FLAG`== 0)=/=>`signal_to_C`);
## Since we don't have the ACW, we will adapt this property on Hack@DAC21 by removing the supervising mode constraint.
## Adaptation to Hack@DAC21: C should not receive meaningful data from P in response to an illegal address transaction.
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv
check_spv -create \
  -name SP12_illegal_addr_rdata_to_cpu \
  -from aes0_wrapper_i.rdata \
  -from_precond { aes0_wrapper_i.en_acct &&
                  aes0_wrapper_i.address[8:3] != 0 &&
                  aes0_wrapper_i.address[8:3] != 1 &&
                  aes0_wrapper_i.address[8:3] != 2 &&
                  aes0_wrapper_i.address[8:3] != 3 &&
                  aes0_wrapper_i.address[8:3] != 4 &&
                  aes0_wrapper_i.address[8:3] != 11 &&
                  aes0_wrapper_i.address[8:3] != 12 &&
                  aes0_wrapper_i.address[8:3] != 13 &&
                  aes0_wrapper_i.address[8:3] != 14 &&
                  aes0_wrapper_i.address[8:3] != 15 } \
  -to ariane_i.axi_resp_i.r.data
## Assertion covered and satisfied

## SP 13 Type: IFT
## Verification Level: IP
## Requirement: C cannot send data associated with an illegal address to P which originates while the ACW is in supervising mode.
## SP Specification Template: //# of Generic Signals to Replace = 4 SP13_SEND_GENERIC: assert iflow(`signal_from_C` when (`acw_w/r_state` == 2'b01) && (`AR/AW_ADDR_VALID_FLAG`== 0)=/=>`signal_to_P`);
## Similar as above, we will adapt this property on Hack@DAC21 by removing the supervising mode constraint.
## Adaptation to Hack@DAC21: C write data must not influence P when the address is illegal
## Sample Module: Controller: ariane.sv Peripheral: aes0_wrapper.sv
check_spv -create \
  -name SP13_illegal_write_to_start \
  -from aes0_wrapper_i.wdata \
  -from_precond { aes0_wrapper_i.en && aes0_wrapper_i.we &&
                  aes0_wrapper_i.address[8:3] != 0 &&
                  aes0_wrapper_i.address[8:3] != 1 &&
                  aes0_wrapper_i.address[8:3] != 2 &&
                  aes0_wrapper_i.address[8:3] != 3 &&
                  aes0_wrapper_i.address[8:3] != 4 &&
                  aes0_wrapper_i.address[8:3] != 5 &&
                  aes0_wrapper_i.address[8:3] != 6 &&
                  aes0_wrapper_i.address[8:3] != 7 &&
                  aes0_wrapper_i.address[8:3] != 8 &&
                  aes0_wrapper_i.address[8:3] != 9 &&
                  aes0_wrapper_i.address[8:3] != 10 &&
                  aes0_wrapper_i.address[8:3] != 16 &&
                  aes0_wrapper_i.address[8:3] != 17 &&
                  aes0_wrapper_i.address[8:3] != 18 &&
                  aes0_wrapper_i.address[8:3] != 19 &&
                  aes0_wrapper_i.address[8:3] != 20 &&
                  aes0_wrapper_i.address[8:3] != 21 &&
                  aes0_wrapper_i.address[8:3] != 22 &&
                  aes0_wrapper_i.address[8:3] != 23 &&
                  aes0_wrapper_i.address[8:3] != 24 &&
                  aes0_wrapper_i.address[8:3] != 25 &&
                  aes0_wrapper_i.address[8:3] != 26 &&
                  aes0_wrapper_i.address[8:3] != 27 &&
                  aes0_wrapper_i.address[8:3] != 28 &&
                  aes0_wrapper_i.address[8:3] != 29 &&
                  aes0_wrapper_i.address[8:3] != 30 &&
                  aes0_wrapper_i.address[8:3] != 31 &&
                  aes0_wrapper_i.address[8:3] != 32 } \
  -to aes0_wrapper_i.start
## Assertion covered and satisfied

## SP 14 Type: IFT
## Verification Level: IP
## Requirement: C cannot receive data from P which originates while the ACW is in decouple mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP14_RECEIVE_GENERIC: assert iflow(`signal_from_P`when (`acw_w/r_state`== 2’b10)=/=>`signal_to_C`);
## Not applicable: no ACW decouple mode / no equivalent isolation state.

## SP 15 Type: IFT
## Verification Level: IP
## Requirement: C cannot send data to P which originates while the ACW is in decouple mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP15_SEND_GENERIC: assert iflow(`signal_from_C`when (`acw_w/r_state`== 2’b10)=/=>`signal_to_P`);
## Not applicable: no ACW decouple mode / no equivalent isolation state.

## SP 16 Type: Trace
## Verification Level: IP
## Requirement: C receives the default AXI signals while the ACW is in decouple mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP16_DEFAULT_GENERIC: assert iflow(`signal_to_C`==`default_AXI_value`unless (`acw_w/r_state` != 2’b10));
## Not applicable: no ACW decouple mode / no equivalent isolation state.

## SP 17 Type: Trace
## Verification Level: IP
## Requirement: The ACW outputs the default AXI signals to the P while the ACW is in decouple mode.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP17_DEFAULT_GENERIC: assert iflow(`signal_to_P`==`default_AXI_value`unless (`acw_w/r_state` != 2’b10));
## Not applicable: no ACW decouple mode / no equivalent isolation state.

## SP 18 Type: IFT
## Verification Level: IP
## Requirement: The anomaly registers are updated with illegal request metadata after the ACW detects an illegal request.
## SP Specification Template: //# of Generic Signals to Replace = 3 SP18_DEFAULT_GENERIC: ;
## We think this template does not properly match the requirement: if anomaly registers should be updated with illegal request metadata, then information flow should exist from the metadata source to the anomaly register.
## SP18 is not directly applicable because Hack@DAC21 lacks ACW-owned anomaly registers for illegal interconnect requests. As a similar-spirit adaptation, we check whether CPU exception metadata propagates into ariane’s CSR/trap-handling state. 
## However, this is more related to CPU's architecture rather than the interconnect. 
## Sample Module: ariane.sv
check_spv -create \
  -name SP18_like_exception_to_epc \
  -from ariane_i.ex_commit \
  -from_precond { ariane_i.ex_commit.valid } \
  -to ariane_i.epc_commit_pcgen
## The assertion is covered and violated, which is expected. Since SP18 describes an update behavior, information flow should exist from the exception metadata to the trap-handling state.

## SP 19 Type: Trace
## Verification Level: Firmware
## Requirement: An interrupt to TE is generated after the ACW detects an illegal request.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP19_INTERRUPT_GENERIC: assert iflow(`INTR_LINE_W/R`== 1 unless (`acw_w/r_state` != 2’b10));
## Hack@DAC21 does not have ACW decouple mode or ACW interrupt, so direct mapping is not reasonable. 
## In Hack@DAC21 acct_wrapper.sv and riscv_peripherals.sv, access control is enforced through combinational gating of request signals using `acc_ctrl_c`. If a request is unauthorized, it is simply blocked and does not propagate to the peripheral. 
## However, there is no explicit detection signal or interrupt mechanism associated with illegal requests.
## Similar Spirit Adaptation: After an exception is committed, ariane.sv should redirect control flow to the trap handler.
## Sample Module: ariane.sv
assert -name SP19 {
  ariane_i.ex_commit.valid |=> ariane_i.set_pc_ctrl_pcgen
}
## The assertion is covered and violated, which is expected (similar as SP18)

## SP 20 Type: IFT
## Verification Level: System
## Requirement: Any C cannot receive data from any region not contained within its ACW’s LACP.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP20_RECEIVE_GENERIC: assert iflow(`unauthorized`=/=>`sig_to_C`);
## Adaptation to Hack@DAC21: When access is denied by acc_ctrl_c, peripheral response data should not flow to controller
## Sample Module: Controller: ariane.sv, Peripheral: aes0 inside riscv_peripherals.sv (using acc_ctrl_c, which originates from acct_wrapper.sv)
check_spv -create \
  -name SP20_unauth_aes0_to_cpu_rdata \
  -from riscv_peripherals_i.aes0_axi_resp.r.data \
  -from_precond { !riscv_peripherals_i.acc_ctrl_c[riscv_peripherals_i.priv_lvl_i][1] } \
  -to ariane_i.axi_resp_i.r.data
## Satisfied and covered

## SP 21 Type: IFT
## Verification Level: System
## Requirement: Any C cannot send data to any region not contained within its ACW’s LACP.
## SP Specification Template: //# of Generic Signals to Replace = 2 SP21_SEND_GENERIC: assert iflow(`sig_from_C`=/=>`unauthorized`);
## Adaptation to Hack@DAC21: Hack@DAC21 does not have ACW LACP (Local Access Control Policy). We map the LACP to the access-control policy encoded by acc_ctrl_c in riscv_peripherals.sv. A region not contained within C’s LACP corresponds to a peripheral whose access-control bit is disabled for the current privilege level.
## The adapted property checks that controller-originated write data cannot influence unauthorized peripheral state. For here, we use key0 as the internal state of AES.
check_spv -create \
  -name SP21 \
  -from ariane_i.axi_req_o.w.data \
  -from_precond { !riscv_peripherals_i.acc_ctrl_c[riscv_peripherals_i.priv_lvl_i][1] } \
  -to riscv_peripherals_i.i_aes0_wrapper.key0
## Satisfied and covered
