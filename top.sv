
import uvm_pkg :: * ;
`ifdef DISABLE_AS_DFI
// User need to include DFI related files here
  `include "user_dfi_files.f"
`endif
`timescale 1ps/1ps
`include "uvm_macros.svh"
`include "krypton_defines.svh"
`include "krypton_enum_package.svh"
`include "tb_top_includes.svh"
module top;

	

  wire [NB_MSTR -1:0][1:0]                              axi_rresp            ;
  //////////////////////////////////////////////////////////////////////
  // AXI4 Interface
  //////////////////////////////////////////////////////////////////////
  reg [`NB_MSTR-1:0] axiClock;
  reg axiResetN;
  
  
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  //APB interface
  //////////////////////////////////////////////////////////////////////
  reg apb_clk;
  reg apb_reset_N;
  apb_interface apb_if(apb_clk,apb_reset_N);
  initial begin
    uvm_config_db #(virtual interface apb_interface)::set(null,"*","apb_interface",apb_if);
  end

`ifdef DISABLE_AS_DFI
  // Below APB Interface can be used by user if user want to use it for configuring DFI
  apb_interface user_apb_if(apb_clk,apb_reset_N);
  initial begin
    uvm_config_db #(virtual interface apb_interface)::set(null,"*","user_apb_interface",user_apb_if);
  end
`endif
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  // I2C Slave Interface
  //////////////////////////////////////////////////////////////////////
  i2c_s_if as_i2c_if();
  wire dut_sda_o;
  wire sda_lcl;
  wand sdaw;

  assign sdaw = (dut_sda_o === 1'b1) ? 1'bz : 1'b0;
  assign sdaw = as_i2c_if.sda;

  assign sda_lcl = sdaw;
  assign as_i2c_if.sda_i = sda_lcl;
  
  
  //////////////////////////////////////////////////////////////////////
  //DIMM interface
  //////////////////////////////////////////////////////////////////////
  //`ifdef AS_IF_HANDLER
    ddr4_module_if idimm_to_dfi();
  //`endif
  ddr4_module_if idimm();
  `ifdef LCOM
  lcom_interface lcom_if();
  assign lcom_if.LCK[0] = lck; 
  assign lcom_if.LCK[1] = !lck;
  assign lcom_i = (lcom_oe == 1'b1) ? 3'b0 : lcom_if.LCOM[1:0];
  assign lcom_if.LCOM[1:0] = (lcom_oe == 1'b1) ? lcom_o[1:0] : 2'b0;
  assign lcom_if.LCOM[2] = lcom_o[2];
  `endif

  `ifdef DDR4
    ddr4_module_if idimm_A();
    ddr4_module_if idimm_B();
  `endif

  `ifdef DRAM_SIM
  assign idimm.CK_t = ddr_clk;
  assign idimm.CK_c = !ddr_clk;
  `endif

  //Virtual Interface instance for DDR4 Monitor
  virtual ddr4_module_if ddr4_interface_ch_vi;
  virtual ddr4_module_if ddr4_interface_A_vi;
  virtual ddr4_module_if ddr4_interface_B_vi;
  virtual i2c_s_if       i2c_if_vi;
  `ifdef LCOM
  virtual lcom_interface lcom_vif;
  `endif
  initial begin
    ddr4_interface_ch_vi = idimm;
    i2c_if_vi = as_i2c_if;
    `ifdef DRAM_SIM
     uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*dram_sim_ins*"),"ddr4_module_if",ddr4_interface_ch_vi);
    `endif
     `ifdef DDR4
       ddr4_interface_A_vi  = idimm_A;
       ddr4_interface_B_vi  = idimm_B;
       `ifdef LCOM
       lcom_vif =  lcom_if;
       `endif
       `ifdef LRDIMM
         uvm_config_db #(virtual interface i2c_s_if)::set(null,$psprintf("*"),"i2c_if",i2c_if_vi);
         `ifdef LCOM
         uvm_config_db #(virtual interface lcom_interface)::set(null,$psprintf("*"),"lcom_if",lcom_vif);
         `endif
         uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*ddr4_mon_agent[0]*"),"ddr4_module_if",ddr4_interface_A_vi);
         uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*ddr4_mon_agent[1]*"),"ddr4_module_if",ddr4_interface_B_vi);
       `else
         uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*ddr4_mon_agent[0]*"),"ddr4_module_if",ddr4_interface_ch_vi);
       `endif
       uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*"),"ddr4_module_if_A",ddr4_interface_A_vi);
       uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*"),"ddr4_module_if_B",ddr4_interface_B_vi);
       uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*"),"hdlr_to_rcd_if",ddr4_interface_ch_vi);
     `else
       uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*ddr4_mon_agent[0]*"),"ddr4_module_if",ddr4_interface_ch_vi);
     `endif
   end
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  //AXI4PC assertion
  //////////////////////////////////////////////////////////////////////
  bit axi_pc_EN = 1;
  generate 
  for(genvar i=0;i<`NB_MSTR;i++)begin : AXI_CHECKER_MODULE
    defparam u_axi4_sva.ADDR_WIDTH = AXI_ADDRWIDTH;
    defparam u_axi4_sva.DATA_WIDTH = `AXI_DATA_WIDTH;       // data bus width, default = 64-bit
    defparam u_axi4_sva.WID_WIDTH = AXI_IDWIDTH;            // (A|W|R|B)ID width
    defparam u_axi4_sva.RID_WIDTH = AXI_IDWIDTH;            // (A|W|R|B)ID width
    Axi4PC #(.RecommendOn(1'b0))u_axi4_sva(.ACLK (axiClock[i] & axi_pc_EN),
                  .ARESETn (axiResetN),
                  .AWID (axi_interface[i].AXI_AWID),
                  .AWADDR (axi_interface[i].AXI_AWADDR),
                  .AWLEN (axi_interface[i].AXI_AWLEN),
                  .AWSIZE (axi_interface[i].AXI_AWSIZE),
                  .AWBURST (axi_interface[i].AXI_AWBURST),
                  .AWLOCK(1'b0),
                  .AWCACHE (4'b0),
                  .AWPROT (3'b0),
                  .AWQOS (4'b0),
                  .AWREGION (4'b0),
                  .AWUSER (0),
                  .AWVALID (axi_interface[i].AXI_AWVALID),
                  .AWREADY (axi_interface[i].AXI_AWREADY),
                  .WLAST (axi_interface[i].AXI_WLAST),
                  .WDATA (axi_interface[i].AXI_WDATA),
                  .WSTRB (axi_interface[i].AXI_WSTRB),
                  .WUSER (0),
                  .WVALID (axi_interface[i].AXI_WVALID),
                  .WREADY (axi_interface[i].AXI_WREADY),
                  .BID (axi_interface[i].AXI_BID),
                  .BRESP (axi_interface[i].AXI_BRESP),
                  .BUSER (0),
                  .BVALID (axi_interface[i].AXI_BVALID),
                  .BREADY (axi_interface[i].AXI_BREADY),
                  .ARID (axi_interface[i].AXI_ARID),
                  .ARADDR (axi_interface[i].AXI_ARADDR),
                  .ARLEN (axi_interface[i].AXI_ARLEN),
                  .ARSIZE (axi_interface[i].AXI_ARSIZE),
                  .ARBURST (axi_interface[i].AXI_ARBURST),
                  .ARLOCK (1'b0),
                  .ARCACHE (4'b0),
                  .ARPROT (3'b0),
                  .ARQOS (4'b0),
                  .ARREGION (4'b0),
                  .ARUSER (0),
                  .ARVALID (axi_interface[i].AXI_ARVALID),
                  .ARREADY (axi_interface[i].AXI_ARREADY),
                  .RID (axi_interface[i].AXI_RID),
                  .RLAST (axi_interface[i].AXI_RLAST),
                  .RDATA (axi_interface[i].AXI_RDATA),
                  .RRESP (axi_interface[i].AXI_RRESP),
                  .RUSER (0),
                  .RVALID (axi_interface[i].AXI_RVALID),
                  .RREADY (axi_interface[i].AXI_RREADY),
                  .CACTIVE (1'b0),
                  .CSYSREQ (1'b0),
                  .CSYSACK (1'b0)
         );
  end
  endgenerate
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  //START // this section instantiates Arastu DDR4 Controller
  //////////////////////////////////////////////////////////////////////
  //parameters which are needed for RTL
  localparam DFI_CTRL_DLY   = 2   ;
  localparam AXI_SIZEWIDTH  = 3   ;
  localparam AXI_BURSTWIDTH = 2   ;
  localparam CMD_ADDR_WIDTH = 32  ;
  localparam PIPE_DATAWIDTH = `AXI_DATA_WIDTH + (AXI_ECC_EN*AXI_ECC_FACTOR*8);
  localparam DFI_DATA_WIDTH = 128 ;
`ifdef DDR4_X16
  localparam BADDR_WIDTH    = 4   ;
`elsif DDR3
  localparam BADDR_WIDTH    = 4   ;
`else
  localparam BADDR_WIDTH    = 4   ;
`endif
  localparam CADDR_WIDTH    = 12  ;
`ifdef DIMM_X32
  localparam DDR_CONFIG     = 32  ;
`else
  localparam DDR_CONFIG     = 64  ;
`endif
  localparam APB_ADDR_WIDTH = 32  ;
`ifdef APB_DW_8
  localparam APB_DATA_WIDTH = 8  ;
`else
  `ifdef APB_DW_16
    localparam APB_DATA_WIDTH = 16  ;
  `else
    localparam APB_DATA_WIDTH = 32  ;
  `endif
`endif

  wire [NB_MSTR -1:0]                                   axi_awvalid          ;
  wire [NB_MSTR -1:0]                                   axi_awready          ;
  wire [NB_MSTR -1:0][AXI_IDWIDTH -1:0]                 axi_awid             ;
  wire [NB_MSTR -1:0][AXI_ADDRWIDTH -1:0]               axi_awaddr           ;
  wire [NB_MSTR -1:0][AXI_SIZEWIDTH -1:0]               axi_awsize           ;// Should be of AXI word size
  wire [NB_MSTR -1:0][8 -1:0]                           axi_awlen            ;
  wire [NB_MSTR -1:0][AXI_BURSTWIDTH -1:0]              axi_awburst          ;

  wire [NB_MSTR -1:0][AXI_DATAWIDTH -1:0]               axi_wdata            ;
  wire [NB_MSTR -1:0][AXI_DATAWIDTH/8 -1:0]             axi_wstrb            ;
  wire [NB_MSTR -1:0]                                   axi_wlast            ;
  wire [NB_MSTR -1:0]                                   axi_wvalid           ;
  wire [NB_MSTR -1:0]                                   axi_wready           ;

  wire [NB_MSTR -1:0]                                   axi_bvalid           ;
  wire [NB_MSTR -1:0]                                   axi_bready           ;
  wire [NB_MSTR -1:0][AXI_IDWIDTH -1:0]                 axi_bid              ;

  wire [NB_MSTR -1:0]                                   axi_arvalid          ;
  wire [NB_MSTR -1:0]                                   axi_arready          ;
  wire [NB_MSTR -1:0][AXI_IDWIDTH -1:0]                 axi_arid             ;
  wire [NB_MSTR -1:0][AXI_ADDRWIDTH -1:0]               axi_araddr           ;
  wire [NB_MSTR -1:0][AXI_SIZEWIDTH -1:0]               axi_arsize           ;// Should be of AXI word size
  wire [NB_MSTR -1:0][8 -1:0]                           axi_arlen            ;
  wire [NB_MSTR -1:0][AXI_BURSTWIDTH -1:0]              axi_arburst          ;

  wire [NB_MSTR -1:0][AXI_DATAWIDTH -1:0]               axi_rdata            ;
  wire [NB_MSTR -1:0][AXI_IDWIDTH   -1:0]               axi_rid              ;
  wire [NB_MSTR -1:0]                                   axi_rlast            ;
  wire [NB_MSTR -1:0]                                   axi_rvalid           ;
  wire [NB_MSTR -1:0]                                   axi_rready           ;
  ///////////////////////////
  // Memory interface As memories are outside of MC
  ///////////////////////////
  //localparam WRMEM_AW                          = 09                            ;
  function integer getBitwidth (
     input integer a
    );
    begin
       getBitwidth = 1; // Change 0 to 1.
       while ( a > (1<<getBitwidth) ) getBitwidth = getBitwidth + 1;
    end
  endfunction

  localparam NB_CMD                            = (NB_MSTR == 4) ? 16 :8        ; // TBD for multiple master we have to increase internal command buffer space
  localparam NB_BYTE_IN_AXI_DATA               = AXI_DATAWIDTH/8               ;
  localparam WR_AXI_REQ_BUF_SIZE_IN_BYTE       = NB_BYTE_IN_AXI_DATA <<(8 + 1) ;
  localparam NB_BYTE_IN_DFI_DATA               = ((((DDR_CONFIG*2) + (AXI_ECC_EN*(8<<1))))/8)     ;                   // TBD.
  localparam NB_LOCATION_OF_DFI_WR             = WR_AXI_REQ_BUF_SIZE_IN_BYTE/NB_BYTE_IN_DFI_DATA +1 ;
  localparam WRBUF_AW                          = getBitwidth(NB_LOCATION_OF_DFI_WR);
  localparam RDBUF_AW                          = WRBUF_AW -1;
  localparam RDBUF_DW                          = (DDR_CONFIG*2*NUM_FREQ_PHASE) + (AXI_ECC_EN*NUM_FREQ_PHASE*(8<<1));  // TBD.
  localparam WRBUF_DW                          = RDBUF_DW + RDBUF_DW/8;
  localparam APB_BUF_BW                        = getBitwidth((1024/PIPE_DATAWIDTH)<<3);

  wire [(NB_CMD - NB_MSTR) -1:0]                        rdbuffer_wren        ;
  wire [(NB_CMD - NB_MSTR) -1:0][RDBUF_DW -1:0]         rdbuffer_wrdata      ;
  wire [(NB_CMD - NB_MSTR) -1:0][RDBUF_AW -1:0]         rdbuffer_wraddr      ;
  wire [(NB_CMD - NB_MSTR) -1:0][RDBUF_AW -1:0]         rdbuffer_rdaddr      ;
  wire [(NB_CMD - NB_MSTR) -1:0]                        rdbuffer_rden        ;
  wire [(NB_CMD - NB_MSTR) -1:0][RDBUF_DW -1:0]         rdbuffer_rddata      ;

  wire [NB_MSTR -1:0]                                   wrbuffer_wren        ;
  wire [NB_MSTR -1:0][WRBUF_AW -1:0]                    wrbuffer_wraddr      ;
  wire [NB_MSTR -1:0][WRBUF_DW -1:0]                    wrbuffer_wrdata      ;
  wire [NB_MSTR -1:0]                                   wrbuffer_rden        ;
  wire [NB_MSTR -1:0][WRBUF_AW -1:0]                    wrbuffer_rdaddr      ;
  wire [NB_MSTR -1:0][WRBUF_DW -1:0]                    wrbuffer_rddata      ;

  wire [PIPE_DATAWIDTH + (PIPE_DATAWIDTH/8)  -1 :0]     apb_wrbuf_wrdata     ; 
  wire [APB_BUF_BW -1:0]                                apb_wrbuf_wraddr     ; 
  wire                                                  apb_wrbuf_wren       ; 
  wire [APB_BUF_BW -1:0]                                apb_wrbuf_rdaddr     ; 
  wire                                                  apb_wrbuf_rden       ; 
  wire [PIPE_DATAWIDTH + PIPE_DATAWIDTH/8 -1:0]         apb_wrbuf_rddata     ; 
  wire [PIPE_DATAWIDTH -1:0]                            apb_rdbuf_wrdata     ; 
  wire [APB_BUF_BW -1:0]                                apb_rdbuf_wraddr     ; 
  wire                                                  apb_rdbuf_wren       ; 
  wire [APB_BUF_BW -1:0]                                apb_rdbuf_rdaddr     ; 
  wire [PIPE_DATAWIDTH -1 :0]                           apb_rdbuf_rddata     ; 

 //assign_axi_for_DDR4_controller
  generate
    for(genvar i=0;i<NB_MSTR;i++) begin//{
      assign axi_awvalid [i]    = axi_interface[i].AXI_AWVALID        ;
      assign axi_awid    [i]    = axi_interface[i].AXI_AWID           ;
      assign axi_awaddr  [i]    = axi_interface[i].AXI_AWADDR         ;
      assign axi_awsize  [i]    = axi_interface[i].AXI_AWSIZE         ;
      assign axi_awlen   [i]    = axi_interface[i].AXI_AWLEN          ;
      assign axi_awburst [i]    = axi_interface[i].AXI_AWBURST        ;

      assign axi_wdata   [i]    = axi_interface[i].AXI_WDATA          ;
      assign axi_wstrb   [i]    = axi_interface[i].AXI_WSTRB          ;
      assign axi_wlast   [i]    = axi_interface[i].AXI_WLAST          ;
      assign axi_wvalid  [i]    = axi_interface[i].AXI_WVALID         ;

      assign axi_bready  [i]    = axi_interface[i].AXI_BREADY         ;

      assign axi_arvalid [i]    = axi_interface[i].AXI_ARVALID        ;
      assign axi_arid    [i]    = axi_interface[i].AXI_ARID           ;
      assign axi_araddr  [i]    = axi_interface[i].AXI_ARADDR         ;
      assign axi_arsize  [i]    = axi_interface[i].AXI_ARSIZE         ;
      assign axi_arlen   [i]    = axi_interface[i].AXI_ARLEN          ;
      assign axi_arburst [i]    = axi_interface[i].AXI_ARBURST        ;

      assign axi_rready  [i]    = axi_interface[i].AXI_RREADY         ;

      assign axi_interface[i].AXI_AWREADY        =    axi_awready [i] ;
      assign axi_interface[i].AXI_WREADY         =    axi_wready  [i] ;
      assign axi_interface[i].AXI_BVALID         =    axi_bvalid  [i] ;
      assign axi_interface[i].AXI_BID            =    axi_bid     [i] ;
      assign axi_interface[i].AXI_ARREADY        =    axi_arready [i] ;
      assign axi_interface[i].AXI_RDATA          =    axi_rdata   [i] ;
      assign axi_interface[i].AXI_RID            =    axi_rid     [i] ;
      assign axi_interface[i].AXI_RLAST          =    axi_rlast   [i] ;
      assign axi_interface[i].AXI_RVALID         =    axi_rvalid  [i] ;
    end//}
  endgenerate 
  bit[2:0] NB_LOGICAL_RANK = `NB_LOGICAL_RANK>>1;  
  `ifndef DFI_BFM
  //instance of ddr4 controller
  ddr4_axi_top #(
    .AXI_NB_MASTERS    ( NB_MSTR                        ),
    .AXI_IDWIDTH       ( AXI_IDWIDTH                    ),
    .AXI_ADDRWIDTH     ( AXI_ADDRWIDTH                  ),
    .AXI_SIZEWIDTH     ( AXI_SIZEWIDTH                  ),
    .AXI_BURSTWIDTH    ( AXI_BURSTWIDTH                 ),
    .AXI_DATAWIDTH     ( AXI_DATAWIDTH                  ),
    .AXI_ECC_EN        ( AXI_ECC_EN                     ),
    .AXI_ECC_FACTOR    ( AXI_ECC_FACTOR                 ),
    `ifdef LRDIMM
     `ifndef SPD_OFF
     .SPD_EN            ( 1'b1                          ),
     `else
     .SPD_EN            ( 1'b0                          ),
     `endif
    `else
    .SPD_EN            ( 1'b0                           ),
    `endif
    .NUM_FREQ_PHASE    ( NUM_FREQ_PHASE                 ),
    .NB_RANK           (`MAX_NB_RANK * `NB_LOGICAL_RANK ),
    .DFI_CTRL_DLY      ( DFI_CTRL_DLY                   ),
//  .CMD_ADDR_WIDTH    ( CMD_ADDR_WIDTH                 ),
    .PIPE_DATAWIDTH    ( PIPE_DATAWIDTH                 ),
    .HAMMING_ECC       ( 0                              ),
    .ECC_ENABLE        ( ECC_ENABLE                     ),
  `ifdef DIFF_CKE
    .COMMON_CKE        ( 0                              ),
  `endif
//  .DFI_DATA_WIDTH    ( DFI_DATA_WIDTH                 ),
  `ifdef SIM_MODE
    .SIM_MODE          ( 1                              ),
  `endif
  `ifdef LCOM
    .LCOM_EN           (1                               ),
  `endif
    .TRR_LOGIC_EN      ( 1                              ),
    .PPR_LOGIC_EN      ( 1                              ),
    .BADDR_WIDTH       ( BADDR_WIDTH                    ),
    .RADDR_WIDTH       ( 18                             ),
    .CADDR_WIDTH       ( CADDR_WIDTH                    ),
    .DDR_CONFIG        ( DDR_CONFIG                     ),
    .APB_ADDR_WIDTH    ( APB_ADDR_WIDTH                 ),
    .APB_DATA_WIDTH    ( APB_DATA_WIDTH                 ),
    .NB_CMD            ( NB_CMD                         ),
    .WRBUF_AW          ( WRBUF_AW                       ),
    .RDBUF_AW          ( RDBUF_AW                       ),
    .WRBUF_DW          ( WRBUF_DW                       ),
    .RDBUF_DW          ( RDBUF_DW                       ),
    .APB_BUF_BW        ( APB_BUF_BW                     ),
    `ifdef DDR_3DS
    .DDR4_3DS_EN       ( 1                              ),
    `endif


    .CLK_NS            ( `APB_CLK_NS                    )
  )  DDR4_Controller(

                  .axi_clk              ( axiClock                          ),
                  .axi_rstn             ( {NB_MSTR{axiResetN}}              ),
                  `ifdef DDR3
                    .DDR3              ( 1'b1                              ),
                  `else
                    .DDR3              ( 1'b0                              ),
                  `endif
                  .*,
                  `ifdef BYPASS_TRAINING
                    .bypass_all_training  ( 1'b1                              ),
                  `else
                    .bypass_all_training  ( 1'b0                              ),
                  `endif
                  //.freq_change_valid    (                                   ),
                  `ifdef DDR4_X4
                    .X4_DEVICE (1'b1),
                  `else 
                    .X4_DEVICE (1'b0),
                  `endif
                  `ifdef DDR4_X16
                    .X16_DEVICE(1'b1),
                  `else
                    .X16_DEVICE(1'b0),
                  `endif
                  `ifdef LRDIMM
                  .RCD_EN               (1'b1                              ),
                  `else
                  .RCD_EN               (1'b0                              ),
                  `endif
                  .DDR4_3DS_CONFIG      (  NB_LOGICAL_RANK                  ),
                  .dfi_address          (as_dfi_if.dfi_address              ), 
                  .dfi_reset_n          (as_dfi_if.dfi_reset_n              ),
           //       .dfi_cs_n             (as_dfi_if.dfi_cs_n                 ),
           //     .dfi_cke              (as_dfi_if.dfi_cke                  ),
           //     .dfi_odt              (as_dfi_if.dfi_odt                  ), 
           //       .dfi_bank             (as_dfi_if.dfi_bank                 ),
                  .dfi_bg               (as_dfi_if.dfi_bg                   ),
                  .dfi_cid              (as_dfi_if.dfi_cid                  ),
                  .dfi_act_n            (as_dfi_if.dfi_act_n                ),
                  .dfi_cas_n            (as_dfi_if.dfi_cas_n                ),
                  .dfi_ras_n            (as_dfi_if.dfi_ras_n                ),
                  .dfi_we_n             (as_dfi_if.dfi_we_n                 ),
                                                   
                  .start_initialization (start_initialization               ), 
                  .dfi_init_start       (as_dfi_if.dfi_init_start           ), 
                  .dfi_init_complete    (as_dfi_if.dfi_init_complete        ), 
          //        .dfi_frequency        (                                   ),
                  .dfi_freq_ratio       (as_dfi_if.dfi_freq_ratio           ),
                                                   
                  .dfi_rdlvl_gate_en    (as_dfi_if.dfi_rdlvl_gate_en        ), 
                  .dfi_rdlvl_en         (as_dfi_if.dfi_rdlvl_en             ), 
                  .dfi_lvl_pattern      (as_dfi_if.dfi_lvl_pattern          ), 
                  .dfi_rdlvl_resp       (as_dfi_if.dfi_rdlvl_resp           ), 
                                                   
                  .dfi_wrlvl_en         (as_dfi_if.dfi_wrlvl_en             ), 
                  .dfi_wrlvl_strobe     (as_dfi_if.dfi_wrlvl_strobe         ), 
                  .dfi_wrlvl_resp       (as_dfi_if.dfi_wrlvl_resp           ), 
              //    .dfi_wrlvl_result     (                                   ), 
                                                   
                  .dfi_rddata_cs_n      (as_dfi_if.dfi_rddata_cs_n          ), 
                  .dfi_rddata_en        (as_dfi_if.dfi_rddata_en            ), 
                  .dfi_rddata_valid     (as_dfi_if.dfi_rddata_valid         ), 

                  //.dfi_rddata           (as_dfi_if.dfi_rddata               ), 
                  //.dfi_rddata_dbi       (as_dfi_if.dfi_rddata_dbi           ), 
                  //.dfi_wrdata           (as_dfi_if.dfi_wrdata               ), 
                  //.dfi_wrdata_mask      (as_dfi_if.dfi_wrdata_mask          ), 
                                                   
                  .dfi_wrdata_cs_n      (as_dfi_if.dfi_wrdata_cs_n          ), 
                  .dfi_wrdata_en        (as_dfi_if.dfi_wrdata_en            ), 
                                                   
       //           .dfi_ctrlupd_ack      (as_dfi_if.dfi_ctrlupd_ack          ), 
       //           .dfi_ctrlupd_req      (as_dfi_if.dfi_ctrlupd_req          ), 
                  .dfi_phyupd_ack       (as_dfi_if.dfi_phyupd_ack           ), 
                  .dfi_phyupd_req       (as_dfi_if.dfi_phyupd_req           ), 
                  .dfi_phylvl_req_cs_n  (as_dfi_if.dfi_phylvl_req_cs_n      ), 
                  .dfi_phylvl_ack_cs_n  (as_dfi_if.dfi_phylvl_ack_cs_n      ), 
                  .dfi_phyupd_type      (as_dfi_if.dfi_phyupd_type          ), 
                                                   
        //          .dfi_lp_ack           (as_dfi_if.dfi_lp_ack               ),
        //          .dfi_lp_ctrl_req      (as_dfi_if.dfi_lp_ctrl_req          ),
        //          .dfi_lp_data_req      (as_dfi_if.dfi_lp_data_req          ),
        //          .dfi_lp_wakeup        (as_dfi_if.dfi_lp_wakeup            ),
        //                                           
        //          .dfi_error            (as_dfi_if.dfi_error                ),
        //          .dfi_error_info       (as_dfi_if.dfi_error_info           ),
                   
                  .alert_n              (as_dfi_if.dfi_alert_n              ),
                  .parity               (as_dfi_if.dfi_parity_in            ),
                   
                  .dfi_dram_clk_disable (as_dfi_if.dfi_dram_clk_disable     ),
                   
                  .mc_intr_o            (apb_if.INTR                        ),
                   
                  .pclk_i               (apb_clk                            ),
                  .prst_ni              (apb_reset_N                        ),
                  .paddr_i              (apb_if.PADDR                       ),
                  .pstartaddr_i         ({APB_ADDR_WIDTH{1'b0}}             ), 
                  .pprot_i              (1'b0                               ), 
                  .psel_i               (apb_if.PSEL                        ),
                  .penable_i            (apb_if.PENABLE                     ),
                  .pwrite_i             (apb_if.PWRITE                      ),
                  .pwdata_i             (apb_if.PWDATA                      ),
                  .pstrb_i              (apb_if.PSTRB                       ),
                   
                  .pready_o             (apb_if.PREADY                      ),
                  .pslverr_o            (apb_if.PSLVERR                     ),
                  .prdata_o             (apb_if.PRDATA                      ),

                   // SPD Interface
                  .i2c_spd_dev_addr     (3'b101                             ), 
                  `ifdef SIM_MODE
                  .i2c_clk_div          (7'h1                               ), 
                  `else
                  .i2c_clk_div          (7'h1                               ), 
                  `endif
                  .i2c_scl_i            (as_i2c_if.scl                      ), 
                  .i2c_scl_oe_n         (as_i2c_if.scl                      ), 
                  .i2c_sda_i            (sda_lcl                            ), 
                  .i2c_sda_oe_n         (dut_sda_o                          ), 
                   `ifdef LCOM
                  .lck                  (lck                                ),//LCOM i/f signals
                  .lrst_n               (lrst_n                             ),
                  .lcom_i               (lcom_i                             ),
                  .lcom_o               (lcom_o                             ),
                  .lcom_oe              (lcom_oe                            ),
                  .lcke                 (lcom_if.LCKE                       ),
                  `endif
                  .rdbuffer_wren        ( rdbuffer_wren                     ),
                  .rdbuffer_wrdata      ( rdbuffer_wrdata                   ),
                  .rdbuffer_wraddr      ( rdbuffer_wraddr                   ),
                  .rdbuffer_rdaddr      ( rdbuffer_rdaddr                   ),
                  .rdbuffer_rden        ( rdbuffer_rden                     ),
                  .rdbuffer_rddata      ( rdbuffer_rddata                   ),
                  .wrbuffer_wren        ( wrbuffer_wren                     ),
                  .wrbuffer_wraddr      ( wrbuffer_wraddr                   ),
                  .wrbuffer_wrdata      ( wrbuffer_wrdata                   ),
                  .wrbuffer_rden        ( wrbuffer_rden                     ),
                  .wrbuffer_rdaddr      ( wrbuffer_rdaddr                   ),
                  .wrbuffer_rddata      ( wrbuffer_rddata                   ),

                  .apb_wrbuf_wrdata     ( apb_wrbuf_wrdata                  ), 
                  .apb_wrbuf_wraddr     ( apb_wrbuf_wraddr                  ), 
                  .apb_wrbuf_wren       ( apb_wrbuf_wren                    ), 
                  .apb_wrbuf_rdaddr     ( apb_wrbuf_rdaddr                  ), 
                  .apb_wrbuf_rden       ( apb_wrbuf_rden                    ), 
                  .apb_wrbuf_rddata     ( apb_wrbuf_rddata                  ), 
                  .apb_rdbuf_wrdata     ( apb_rdbuf_wrdata                  ), 
                  .apb_rdbuf_wraddr     ( apb_rdbuf_wraddr                  ), 
                  .apb_rdbuf_wren       ( apb_rdbuf_wren                    ), 
                  .apb_rdbuf_rdaddr     ( apb_rdbuf_rdaddr                  ), 
                  .apb_rdbuf_rddata     ( apb_rdbuf_rddata                  )  

      );

      generate
        for(genvar PhaseIndex=0;PhaseIndex < NUM_FREQ_PHASE;PhaseIndex++) begin
          assign as_dfi_if.dfi_bank        [PhaseIndex] = dfi_bank           [PhaseIndex];
          assign as_dfi_if.dfi_cs_n        [PhaseIndex] = dfi_cs_n           [PhaseIndex];
          assign as_dfi_if.dfi_cke         [PhaseIndex] = dfi_cke            [PhaseIndex];
          assign as_dfi_if.dfi_odt         [PhaseIndex] = dfi_odt            [PhaseIndex];

          assign dfi_rddata                [PhaseIndex] [MAX_DIMM_DQ_BITS -1 : 0]                    = as_dfi_if.dfi_rddata      [PhaseIndex] [MAX_DIMM_DQ_BITS -1 : 0]                  ;
          assign dfi_rddata_dbi            [PhaseIndex] [MAX_DIMM_DM_BITS -1 : 0]                    = as_dfi_if.dfi_rddata_dbi  [PhaseIndex] [MAX_DIMM_DM_BITS -1 : 0]                  ;
          assign as_dfi_if.dfi_wrdata      [PhaseIndex] [MAX_DIMM_DQ_BITS -1 : 0]                    = dfi_wrdata                [PhaseIndex] [MAX_DIMM_DQ_BITS -1 : 0]                  ;
          assign as_dfi_if.dfi_wrdata_mask [PhaseIndex] [MAX_DIMM_DM_BITS -1 : 0]                    = dfi_wrdata_mask           [PhaseIndex] [MAX_DIMM_DM_BITS -1 : 0]                  ;

          assign dfi_rddata                [PhaseIndex] [MAX_DFI_DATA_BITS -1 : MAX_DFI_DATA_BITS/2] = as_dfi_if.dfi_rddata      [PhaseIndex] [MAX_DIMM_DQ_BITS * 2 -1 : MAX_DIMM_DQ_BITS];
          assign dfi_rddata_dbi            [PhaseIndex] [MAX_DFI_DM_BITS   -1 : MAX_DFI_DM_BITS  /2] = as_dfi_if.dfi_rddata_dbi  [PhaseIndex] [MAX_DIMM_DM_BITS * 2 -1 : MAX_DIMM_DM_BITS];
          assign as_dfi_if.dfi_wrdata      [PhaseIndex] [MAX_DIMM_DQ_BITS * 2 -1 : MAX_DIMM_DQ_BITS] = dfi_wrdata                [PhaseIndex] [MAX_DFI_DATA_BITS -1 : MAX_DFI_DATA_BITS/2];
          assign as_dfi_if.dfi_wrdata_mask [PhaseIndex] [MAX_DIMM_DM_BITS * 2 -1 : MAX_DIMM_DM_BITS] = dfi_wrdata_mask           [PhaseIndex] [MAX_DFI_DM_BITS   -1 : MAX_DFI_DM_BITS  /2];

        end
      endgenerate

    `endif
  //////////////////////////////////////////////////////////////////////
  //END // this section instantiates Arastu DDR4 Controller
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  //START // this section instantiates  Micron DDR4 Model
  //////////////////////////////////////////////////////////////////////
`ifdef MICRON_DDR_MODEL
  `ifndef DDR3
    `ifdef DDR4_2G
        parameter UTYPE_density CONFIGURED_DENSITY = _2G;
    `elsif DDR4_4G
        parameter UTYPE_density CONFIGURED_DENSITY = _4G;
    `elsif DDR4_8G
        parameter UTYPE_density CONFIGURED_DENSITY = _8G;
    `else //if DDR4_16G
        parameter UTYPE_density CONFIGURED_DENSITY = _16G;
    `endif

    `ifdef LRDIMM
      ddr4_dimm #(.CONFIGURED_DQ_BITS(CONFIGURED_DQ_BITS), .CONFIGURED_DENSITY(CONFIGURED_DENSITY),.CONFIGURED_RANKS(`NB_LOGICAL_RANK)) dimm_instance(idimm_A); // For DDR4 DIMM Only
      ddr4_dimm #(.CONFIGURED_DQ_BITS(CONFIGURED_DQ_BITS), .CONFIGURED_DENSITY(CONFIGURED_DENSITY),.CONFIGURED_RANKS(`NB_LOGICAL_RANK)) dimm_instance_B(idimm_B); // For DDR4 DIMM Only
    `else
      ddr4_dimm #(.CONFIGURED_DQ_BITS(CONFIGURED_DQ_BITS), .CONFIGURED_DENSITY(CONFIGURED_DENSITY),.CONFIGURED_RANKS(`NB_LOGICAL_RANK)) dimm_instance(idimm); // For DDR4 Monolithic Only
    `endif
  `else
    ddr4_dimm  dimm_instance(idimm);
  `endif
    //`ifdef AS_IF_HANDLER
      initial begin
        uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*as_mem_if_hndlr*"),"idimm_to_dfi",idimm_to_dfi);
        uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*as_mem_if_hndlr*"),"idimm_to_memory",idimm);
      end
    //`endif

`endif

  //////////////////////////////////////////////////////////////////////
  //END   // this section instantiates  Micron DDR4 Model
  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  //DFI Interface instance
  //////////////////////////////////////////////////////////////////////
  krypton_dfi_interface #(.BUS_WIDTH(MAX_DIMM_DQ_BITS),.DQ_WIDTH(CONFIGURED_DQ_BITS),.DM_WIDTH(MAX_DIMM_DM_BITS),.NB_RANK(`MAX_NB_RANK),.NB_PHASE(NUM_FREQ_PHASE)) as_dfi_if();
  assign as_dfi_if.dfi_clk = dfi_clk;
  assign as_dfi_if.dram_clk = ddr_clk;
  //assign as_dfi_if.dfi_freq_ratio = $clog2(NUM_FREQ_PHASE);

  `ifdef DISABLE_AS_DFI
  // User's DFI Instantiation
    user_dfi #(.BUS_WIDTH(MAX_DIMM_DQ_BITS)) user_dfi_inst(.as_dfi_if(as_dfi_if), .idimm_to_dfi(idimm_to_dfi),.apb_if(user_apb_if));
  `endif

  initial begin
    uvm_config_db #(virtual interface krypton_dfi_interface  #(.BUS_WIDTH(MAX_DIMM_DQ_BITS),.DQ_WIDTH(CONFIGURED_DQ_BITS),.DM_WIDTH(MAX_DIMM_DM_BITS),.NB_RANK(`MAX_NB_RANK),.NB_PHASE(NUM_FREQ_PHASE)))::set(null,$psprintf("*as_dfi*"),"dfi_if",as_dfi_if);
    //`ifdef AS_IF_HANDLER
      uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*as_dfi*"),"dram_if",idimm_to_dfi);
    //`else
    //  uvm_config_db #(virtual interface ddr4_module_if)::set(null,$psprintf("*as_dfi*"),"dram_if",idimm);
    //`endif
  end
  //////////////////////////////////////////////////////////////////////
  //clocks generation
  //////////////////////////////////////////////////////////////////////

  `ifdef AXI_MSTR_0_PRESENT
    `AS_CLOCK_GENERATE(axiClock[0],`AXI_CLK_0)
  `endif
  
  `ifdef AXI_MSTR_1_PRESENT
    `AS_CLOCK_GENERATE(axiClock[1],`AXI_CLK_1)
  `endif
  
  `ifdef AXI_MSTR_2_PRESENT
    `AS_CLOCK_GENERATE(axiClock[2],`AXI_CLK_2)
  `endif
  
  `ifdef AXI_MSTR_3_PRESENT
    `AS_CLOCK_GENERATE(axiClock[3],`AXI_CLK_3)
  `endif

   `AS_CLOCK_GENERATE(apb_clk,`APB_CLK_PERIOD)

   `ifdef LCOM
     `AS_CLOCK_GENERATE(ddr_clk,timings.tCK[0])//250 MHz
   `else
     `AS_CLOCK_GENERATE(ddr_clk,timings.tCK[dfi_frequency])
   `endif

   `AS_CLOCK_DIVIDE(dfi_clk,ddr_clk,NUM_FREQ_PHASE)
    
   `ifdef LCOM
   `AS_CLOCK_GENERATE(lck,(timings.tCK[0]/4))
   `endif

  //////////////////////////////////////////////////////////////////////

  //////////////////////////////////////////////////////////////////////
  //reset generation
  //////////////////////////////////////////////////////////////////////

  initial begin//{
    apb_reset_N <= 0;
    dfi_rstn <= 0;
    start_initialization <= 0;
    axiResetN <= 0;
    `ifdef LCOM
    lrst_n <=0;
    `endif
  `ifdef DISABLE_AS_DFI
  // Drive Reset Signals
  `else
    #(5 * `APB_CLK_PERIOD);
  `endif
    apb_reset_N <= 1;
    dfi_rstn <= 1;
    #1000 start_initialization <= 1;
    axiResetN <= 1;
    `ifdef LCOM
    lrst_n <=1;
    `endif
  end//}
  //////////////////////////////////////////////////////////////////////


`ifdef DUMP_VCD
	initial $dumpfile("krypton.vcd");
	initial  begin//{
		$dumpvars(0,top);
	end//}
`endif


  //run uvm test
  initial begin//{
    string test_name;
    if($value$plusargs("UVM_TESTNAME=%s",test_name))
    run_test(test_name);
  end//}

  int temp_range = 2'b11;
  event temp_range_changed;
  initial begin
    #10us;

    while(1) begin
      temp_range = $urandom_range(2,0);
      -> temp_range_changed;
      $display($time," TOP_INFO :: setting temperature range to : %2b",temp_range);
    `ifdef SIM_MODE
      #15us;
    `else
      #30ms;
    `endif
    end //while ends
  end
  /////////////////////////////
  // Memory instance 
  genvar i;
  generate
      for (i=0 ; i<NB_CMD - NB_MSTR ; i=i+1) 
      begin : rdbuf
      ddr_ram #(
         .ADDR_WIDTH  (RDBUF_AW),
         .DATA_WIDTH  (RDBUF_DW)
      ) ddr_ram_inst (
         .clk    (dfi_clk    ),
         .rstn   (dfi_rstn   ),
         .wdata  (rdbuffer_wrdata [i]),
         .waddr  (rdbuffer_wraddr [i]),
         .wren   (rdbuffer_wren   [i]),
         .rdata  (rdbuffer_rddata [i]),
         .raddr  (rdbuffer_rdaddr [i]),
         .rden   (rdbuffer_rden   [i]                      )
      );
      end
     for (i=0 ; i<NB_MSTR ; i=i+1) 
     begin : wrbuf
       ddr_ram #(
          .ADDR_WIDTH  (WRBUF_AW      ),
          .DATA_WIDTH  (WRBUF_DW      )
       ) ddr_ram_inst (
          .clk    (dfi_clk    ),
          .rstn   (dfi_rstn   ),
          .wdata  (wrbuffer_wrdata[i] ),
          .waddr  (wrbuffer_wraddr[i] ),
          .wren   (wrbuffer_wren  [i] ),
          .rdata  (wrbuffer_rddata[i] ),
          .raddr  (wrbuffer_rdaddr[i] ),
          .rden   (wrbuffer_rden  [i] )
       );
     end
   endgenerate

 //////////////////////////////////////////
 // TEST MODE RAM Instances
 //////////////////////////////////////////

 ddr_dpram 
 #(
    .ADDR_WIDTH  (APB_BUF_BW                                                                                   ),
    .DATA_WIDTH  (PIPE_DATAWIDTH + (PIPE_DATAWIDTH/8)                                                          )
  ) 
  apb_wrram_inst 
  (
     .wrclk  (apb_clk           ), 
     .rdclk  (dfi_clk           ), 
     .rstn   (dfi_rstn          ), 
     .wdata  (apb_wrbuf_wrdata  ), 
     .waddr  (apb_wrbuf_wraddr  ), 
     .wren   (apb_wrbuf_wren    ), 
     .rdata  (apb_wrbuf_rddata  ), 
     .raddr  (apb_wrbuf_rdaddr  ), 
     .rden   (apb_wrbuf_rden    )  
  );

 ddr_dpram 
 #(
    .ADDR_WIDTH  (APB_BUF_BW                    ),
    .DATA_WIDTH  (PIPE_DATAWIDTH                )
  ) 
  apb_rdram_inst 
  (
    .wrclk  (dfi_clk                            ),
    .rdclk  (apb_clk                            ),
    .rstn   (dfi_rstn                           ),
    .wdata  (apb_rdbuf_wrdata                   ),
    .waddr  (apb_rdbuf_wraddr                   ),
    .wren   (apb_rdbuf_wren                     ),
    .rdata  (apb_rdbuf_rddata                   ),
    .raddr  (apb_rdbuf_rdaddr                   ),
    .rden   (1'b1                               )
  );

endmodule : top
