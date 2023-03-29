module fir_7dsp48
#(
    CoefsFile="testcoef.txt",
    int INDATA_WIDTH=16,
    int OUTDATA_WIDTH=16,
    int TRUNCATION=16,
    int FILT_DEPTH=64
)
(
    input logic clk_main,
    input logic indata_vld,
    input logic [INDATA_WIDTH-1:0] data_in,
    output logic [OUTDATA_WIDTH-1:0] data_out,
    output logic outdata_vld
);

logic [47:0] load_data [FILT_DEPTH/2], dsp_out [FILT_DEPTH/2];
logic [24:0] preadder1 [FILT_DEPTH/2], preadder2 [FILT_DEPTH/2];
logic [17:0] multiplier [FILT_DEPTH/2];
logic [INDATA_WIDTH-1:0] preadd_in0 [FILT_DEPTH], preadd_in1 [FILT_DEPTH];
logic [INDATA_WIDTH-1:0] taps_reg [FILT_DEPTH];
logic [FILT_DEPTH+5:0] enbl_reg;
logic [INDATA_WIDTH-1:0] reg_data_pre0 [FILT_DEPTH/2][3*(FILT_DEPTH/2)];
logic [INDATA_WIDTH-1:0] reg_data_pre1 [FILT_DEPTH/2][3*(FILT_DEPTH/2)];


logic [15:0] COEF_FILT [FILT_DEPTH/2-1:0];
logic [15:0] COEF_MEM  [FILT_DEPTH/2-1:0];


initial begin
    $readmemb(CoefsFile, COEF_FILT);
    for (int h=0; h <= FILT_DEPTH/2-1; h++) begin
        COEF_MEM[h] = COEF_FILT[h];
        taps_reg[h] = 0;
        taps_reg[FILT_DEPTH-1-h] = 0;
    end
end

always_comb begin : mult_block
    for (int h=0; h <= FILT_DEPTH/2-1; h++) begin  
        multiplier[h] = signed'(COEF_MEM[h]); 
    end
end


initial begin
    assert (INDATA_WIDTH <= 25 && INDATA_WIDTH >= 1) else $error("Wrong INDATA_WIDTH. INDATA_WIDTH must be from 1 to 25");
    assert (OUTDATA_WIDTH <= 43 && OUTDATA_WIDTH >= 1) else $error("Wrong OUTDATA_WIDTH. INDATA_WIDTH must be from 1 to 43");
    assert (TRUNCATION <= 43 && TRUNCATION >= 0) else $error("Wrong TRUNCATION. TRUNCATION must be from 0 to 43");
end

assign load_data[0]=48'd0;

genvar i;
generate
    for (i=0; i <= FILT_DEPTH/2-2; i++) begin
        assign load_data[i+1] = dsp_out[i];
    end
endgenerate


assign data_out=signed'(dsp_out[FILT_DEPTH/2-1]>>>TRUNCATION);

generate
    genvar j;
    for (j=0; j <= FILT_DEPTH/2-1; j++) begin
        assign preadder1[j] = signed'(preadd_in0[j]);
        assign preadder2[j] = signed'(preadd_in1[j]);
        
        ADD_PRE_MULT_PRIM DSP_PRIM
        (
            .PRODUCT(dsp_out[j]),
            .CARRYIN(1'b0),
            .CLK(clk_main),
            .CE(1'b1),
            .LOAD(1'b1),
            .LOAD_DATA(load_data[j]),
            .MULTIPLIER(multiplier[j]),
            .PREADD2(preadder1[j]),
            .PREADD1(preadder2[j]),
            .RST(1'b0)
        );
    end
endgenerate

always_ff @( posedge clk_main ) begin : taps_block
    taps_reg[0]<=data_in;
    for (int i = 0; i<=FILT_DEPTH-2 ; i++) begin
        taps_reg[i+1]<=taps_reg[i];
    end
end

always_ff @( posedge clk_main ) begin : vld_block
    enbl_reg[0]<=indata_vld;
    for (int i = 0; i<=FILT_DEPTH+4 ; i++) begin
        enbl_reg[i+1]<=enbl_reg[i];
    end
    outdata_vld<=enbl_reg[FILT_DEPTH+5];
end

always_ff @( posedge clk_main ) begin : delay_comp_block
    for (int j = 0; j<=FILT_DEPTH/2-1 ; j++) begin
        reg_data_pre0[j][0]<=taps_reg[j];
        reg_data_pre1[j][0]<=taps_reg[FILT_DEPTH-1-j];
        
        for (int i = 0; i<=2*(j+1)-1 ; i++) begin
            reg_data_pre0[j][i+1]<=reg_data_pre0[j][i];
            reg_data_pre1[j][i+1]<=reg_data_pre1[j][i]; 
        end

        preadd_in0[j]<=reg_data_pre0[j][2*(j+1)];
        preadd_in1[j]<=reg_data_pre1[j][2*(j+1)];
    end
end
endmodule