// Based of MATBI AIHW Course Project
// https://www.inflearn.com/course/%EC%8B%A4%EC%A0%84-%ED%95%98%EB%93%9C%EC%9B%A8%EC%96%B4-%EC%84%A4%EA%B3%84/dashboard

`include "timescale.vh"

module cnn_acc_ci (
    clk,
    reset_n,
    soft_reset_i,
    in_valid_i,
    cnn_weight_i,
    in_fmap_i,
    ot_valid_o,
    ot_ci_acc_o
);
`include "defines_cnn_core.vh"
localparam LATENCY = 1;

input clk;
input reset_n;
input soft_reset_i;
input in_valid_i;
input [CI*KX*KY*W_BW-1:0] cnn_weight_i;
input [CI*KX*KY*I_F_BW-1:0] in_fmap_i;
output ot_valid_o;
output [ACI_BW-1:0] ot_ci_acc_o;

// enable signal shift
wire ce;
reg r_valid;
wire [CI-1:0] w_ot_valid;

always @ (posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        r_valid <= {LATENCY{1'b0}};
    end else if (soft_reset_i) begin
        r_valid <= {LATENCY{1'b0}};
    end else begin
        r_valid <= &w_ot_valid;
    end
end

assign ce = r_valid;

// accumulation of mul_acc instances
wire [CI-1:0] w_in_valid;
wire [CI*AK_BW-1:0] w_ot_kernel_acc;
wire [ACI_BW-1:0] w_ot_ci_acc;
reg [ACI_BW-1:0] r_ot_ci_acc;

// divide up for each CI and send to cnn_kernel
assign w_in_valid = {CI{in_valid_i}};

genvar ci;
generate
    for (ci = 0; ci < CI; ci=ci+1) begin
        cnn_kernel u_cnn_kernel(
            .clk(clk),
            .reset_n(reset_n),
            .soft_reset_i(soft_reset_i),
            .in_valid_i(w_in_valid[ci]),
            .cnn_weight_i(cnn_weight_i[(ci*(KX*KY*W_BW))+:KX*KY*W_BW]),
            .f_map_i(in_fmap_i[(ci*(KX*KY*I_F_BW))+:KX*KY*I_F_BW]),
            .ot_valid_o(w_ot_valid[ci]),
            .ot_kernel_acc_o(w_ot_kernel_acc[ci*AK_BW+:AK_BW])
        );
    end
endgenerate

reg [ACI_BW-1:0] ot_ci_acc;
integer kernel_acc;
always @ (*) begin
    ot_ci_acc = {ACI_BW{1'b0}};
    for (kernel_acc = 0; kernel_acc < CI; kernel_acc=kernel_acc+1) begin
        ot_ci_acc = ot_ci_acc + w_ot_kernel_acc[kernel_acc*AK_BW+:AK_BW];
    end
end


assign w_ot_ci_acc = ot_ci_acc;

always @ (posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        r_ot_ci_acc[ACI_BW-1:0] <= {ACI_BW{1'b0}};
    end else if (soft_reset_i) begin
        r_ot_ci_acc[ACI_BW-1:0] <= {ACI_BW{1'b0}};
    end else if (&w_ot_valid) begin
        r_ot_ci_acc[ACI_BW-1:0] <= w_ot_ci_acc[ACI_BW-1:0];
    end
end

assign ot_valid_o = r_valid;
assign ot_ci_acc_o = r_ot_ci_acc;

endmodule