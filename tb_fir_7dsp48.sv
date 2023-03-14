`timescale 1ns/1ps 
module tb_fir_7dsp48
#(
    real clk_period=10,//ns
    int  FILT_DEPTH=64,
    int  FILT_WIDTH=16,
    string file_name="F:/works/_source/_fir/testcoef.txt"
);

logic clk_main=1'b0;
logic [FILT_WIDTH-1:0] data_mmr [FILT_DEPTH/2];
logic [FILT_WIDTH-1:0] imp [FILT_DEPTH];
logic [FILT_WIDTH+1:0] step [FILT_DEPTH];
logic [FILT_WIDTH-1:0] tmp [0:FILT_DEPTH/2-1];
logic [17:0] accum=0;
logic [15:0]datain;
logic [17:0]dataout;
logic indata_vld,outdata_vld;
integer cntr=0,error=0;
logic imp_done,step_done;

typedef enum logic [2:0] {S0, S1, S2, S3, S4} statetype;
statetype state=S0;

always #(clk_period/2*1ns) clk_main=~clk_main;

fir_7dsp48 
#(
    .INDATA_WIDTH(16),
    .OUTDATA_WIDTH(18),
    .TRUNCATION(0),
    .FILT_DEPTH(FILT_DEPTH),
    .CoefsFile(file_name)
)
DUT
(
    .clk_main(clk_main), 
    .indata_vld(indata_vld),
    .data_in(datain),
    .data_out(dataout),
    .outdata_vld(outdata_vld)
);

initial begin
    $display("reading coefficient...");
    $readmemb(file_name, data_mmr);
    $display("end reading.");
    
    for (int i = 0; i<=FILT_DEPTH/2-1;i++ ) begin
        tmp[i]= data_mmr[FILT_DEPTH/2-1-i];
    end
    imp={data_mmr,tmp};

    for (int i = 0; i<=FILT_DEPTH-1;i++ ) begin
        accum=signed'(accum)+signed'(imp[i]);
        step[i]= accum;
    end

    $display(" ############# start impulse test ############# ");
    wait(imp_done);
    $display("test completed with %d errors", error);
    $display(" ############# finish impulse test ############# ");
    $display(" ############# start step test ############# ");
    wait(step_done);
    $display("test completed with %d errors", error);
    $display(" ############# finish step test ############# ");
    $finish;
end

always_ff @( posedge clk_main ) begin : compare
    case (state)
    S0: begin
        cntr<=0;
        error<=0;
        imp_done<=1'b0;
        step_done<=1'b0;
        if(cntr<FILT_DEPTH-1) begin
            cntr<=cntr+1;
            state<=S0;
            indata_vld<=1'b0;
            datain<=16'd0;
        end
        else begin
            state<=S1;
            cntr<=0;
            indata_vld<=1'b1;
            datain<=16'd1;
        end
    end

    S1:begin
        indata_vld<=1'b1;
        datain<=16'd0;
        if(outdata_vld) begin
            if(cntr<FILT_DEPTH-1) begin
                cntr<=cntr+1;
                state<=S1;
            end
            else begin
                state<=S2;
                cntr<=0;
            end

            if(signed'(dataout)!=signed'(imp[cntr])) begin
                error<=error+1;
            end
        end
    end
    
    S2:begin
        imp_done<=1'b1;
        if(cntr<FILT_DEPTH+9) begin
            cntr<=cntr+1;
            state<=S2;
            indata_vld<=1'b0;
            datain<=16'd0;
        end
        else begin
            state<=S3;
            cntr<=0;
            indata_vld<=1'b1;
            datain<=16'd1;
            error<=0;
        end
    end

    S3:begin
        indata_vld<=1'b1;
        datain<=16'd1;
        if(outdata_vld) begin
            if(cntr<FILT_DEPTH-1) begin
                cntr<=cntr+1;
                state<=S3;
            end
            else begin
                state<=S4;
                cntr<=0;
            end

            if(signed'(dataout)!=signed'(step[cntr])) begin
                error<=error+1;
            end
        end
    end

    S4:begin
        step_done<=1'b1;
    end

    endcase
end

endmodule 