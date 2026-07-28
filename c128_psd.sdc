#==============================================================================
# C128 Calypso->MiST->Poseidon SDC
#==============================================================================

# --- Base clocks ---
create_clock -name {CLOCK_50} -period 20.000 [get_ports {CLOCK_50}]
create_clock -name {SPI_SCK}  -period 41.666 [get_ports {SPI_SCK}]

# Automatically constrain PLL and other generated clocks
derive_pll_clocks -create_base_clocks

# Automatically calculate clock uncertainty due to jitter and other effects.
derive_clock_uncertainty

#------------------------------------------------------------------------
# Convenience handles for the two PLL outputs
#   clk[0] = 64 MHz  (27 * 64/27)  -> SDRAM clock
#   clk[1] = 32 MHz  (27 * 32/27)  -> system clock (CPUs / VIC / VDC)
#------------------------------------------------------------------------
set sys_clk    {pll|altpll_component|auto_generated|pll1|clk[1]}
set sdram_clk  {pll|altpll_component|auto_generated|pll1|clk[0]}

# --- Async clock groups ---
set_clock_groups -asynchronous \
    -group [get_clocks {SPI_SCK}] \
    -group [get_clocks {CLOCK_50}] \
    -group [get_clocks $sys_clk] \
    -group [get_clocks $sdram_clk]

#------------------------------------------------------------------------
# SDRAM I/O delays (unchanged from original, referenced to clk[0]=64MHz)
#------------------------------------------------------------------------
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 6.4  [get_ports SDRAM_DQ[*]]
set_input_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min 3.2  [get_ports SDRAM_DQ[*]]

set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -max 1.5  [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]
set_output_delay -clock [get_clocks $sdram_clk] -reference_pin [get_ports {SDRAM_CLK}] -min -0.8 [get_ports {SDRAM_D* SDRAM_A* SDRAM_BA* SDRAM_n* SDRAM_CKE}]

#------------------------------------------------------------------------
# CPU (clk[1]/32MHz) -> SDRAM controller (clk[0]/64MHz) address path
#
# STA shows ~-3.8ns setup violations on paths from CPU/T65/T80 registers
# (PC, BAH, Set_Addr_To, BusAck, etc.) into sdram|sd_addr[*], with the
# relationship computed as a single 64MHz-domain cycle (15.625ns) but
# real data delay of ~18.6-19.0ns. The CPU only changes its address bus
# once per 32MHz cycle (i.e. once per TWO 64MHz cycles), so this is a
# multicycle path of 2 with respect to the faster sdram_clk domain.
#------------------------------------------------------------------------
set_multicycle_path -from [get_clocks $sys_clk] -to [get_clocks $sdram_clk] -setup -end 2
set_multicycle_path -from [get_clocks $sys_clk] -to [get_clocks $sdram_clk] -hold  -end 1

#------------------------------------------------------------------------
# VDC CPU-register-write -> internal sync/counter comparator chain
#
# STA shows large setup violations from vdc_top|reg_h*[*]/reg_v*[*]
# (R2/R4/R5/R6/R7/R9 etc, written occasionally by the CPU via the VDC
# register interface) into internal state registers of vdc_signals_h /
# vdc_signals_v (vsCount, vsBegin, hsCount, etc), with ~100ns of
# combinational delay through the horizontal/vertical counter and
# comparator chains spanning both submodules.
#
# These CPU-written timing registers are effectively static (set once at
# init, occasionally changed) and the downstream sync logic only needs to
# settle once per scanline/frame, i.e. many clk[1] (32MHz) cycles later.
# Treat all reg_h*/reg_v* -> vdc_signals_h/vdc_signals_v register paths as
# multicycle (4 setup / 3 hold) rather than single-cycle.
#------------------------------------------------------------------------
set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_h*[*]}] \
                     -to   [get_registers {*vdc_signals_h:*|*}] \
                     -setup -end 4
set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_h*[*]}] \
                     -to   [get_registers {*vdc_signals_h:*|*}] \
                     -hold  -end 3

set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_h*[*]}] \
                     -to   [get_registers {*vdc_signals_v:*|*}] \
                     -setup -end 4
set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_h*[*]}] \
                     -to   [get_registers {*vdc_signals_v:*|*}] \
                     -hold  -end 3

set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_v*[*]}] \
                     -to   [get_registers {*vdc_signals_v:*|*}] \
                     -setup -end 4
set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_v*[*]}] \
                     -to   [get_registers {*vdc_signals_v:*|*}] \
                     -hold  -end 3

set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_v*[*]}] \
                     -to   [get_registers {*vdc_signals_h:*|*}] \
                     -setup -end 4
set_multicycle_path -from [get_registers {*vdc_top:vdc|reg_v*[*]}] \
                     -to   [get_registers {*vdc_signals_h:*|*}] \
                     -hold  -end 3
