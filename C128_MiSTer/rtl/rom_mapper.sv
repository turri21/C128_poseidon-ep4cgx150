/*
   rom_mapper.sv - CPU -> SDRAM address translation for SiDi C128 (no cartridge support)

   This replaces cartridge.sv for builds with CRT/GeoRAM cartridge emulation
   disabled. The original cartridge.sv did two unrelated jobs in one module:

     1) CRT/GeoRAM cartridge banking (the part that was intentionally cut
        for LE budget reasons)
     2) Translating the C128 CPU address bus into the correct SDRAM offset
        for normal system RAM, the system ROM bank currently selected by
        the core (sysRom/sysRomBank), and the internal function ROM
        (romFL/romFH)

   (2) is NOT cartridge-specific - it's the core's normal memory map and is
   required for the machine to boot at all, cartridge or not. Tying
   cart_addr/cart_ce/cart_we to constants (as in the original SiDi edit)
   removed this translation entirely, which is why ROM/RAM accesses never
   reached the right SDRAM location and BASIC never executed.

   This module keeps only the address-translation behavior, with the
   per-cartridge-ID case statement, CRT loading state machine, GeoRAM, and
   freeze/NMI cart logic removed.
*/

module rom_mapper
#(
   parameter RAM_ADDR,
   parameter ROM_ADDR,
   parameter IFR_ADDR
)
(
   input             reset_n,

   // Internal function ROM (loaded via OSD "load Internal Function ROM" /
   // boot2.rom). cart_int_rom is a presence/size mask per 16K segment,
   // cart_bank_int selects which bank is currently paged in.
   input       [6:0] cart_int_rom,
   input       [4:0] cart_bank_int,

   // Driven by fpga64_sid_iec: which system ROM bank (BASIC/KERNAL/etc)
   // is currently selected.
   input             sysRom,
   input       [4:0] sysRomBank,

   // Internal function ROM select strobes from fpga64_sid_iec.
   input             romFL,
   input             romFH,

   input             mem_write,
   input             mem_ce,
   output            mem_ce_out,
   output            mem_write_out,

   input      [17:0] addr_in,        // CPU address
   output reg [24:0] addr_out,       // translated SDRAM address
   output reg        data_floating   // 1 = no ROM image present at this address
);

// No cartridge / GeoRAM IO decode logic remains, so SDRAM ce/we are a
// straight pass-through of the CPU's own request.
assign mem_ce_out    = mem_ce;
assign mem_write_out = mem_write;

always @* begin
   data_floating = 0;

   // Default: plain system RAM
   addr_out = {7'(RAM_ADDR>>18), addr_in};

   if (reset_n) begin
      // System ROM bank (BASIC/KERNAL/editor/etc) selected by the core
      if (sysRom) addr_out[24:12] = {8'(ROM_ADDR>>17), sysRomBank};

      // Internal function ROM, low/high 16K halves
      if (romFL && !mem_write) begin
         addr_out[24:14] = {5'(IFR_ADDR>>20), cart_bank_int & cart_int_rom[6:2], 1'b0};
         data_floating   = ~cart_int_rom[0];
      end
      if (romFH && !mem_write) begin
         addr_out[24:14] = {5'(IFR_ADDR>>20), cart_bank_int & cart_int_rom[6:2], 1'b1};
         data_floating   = ~cart_int_rom[1];
      end
   end
end

endmodule
