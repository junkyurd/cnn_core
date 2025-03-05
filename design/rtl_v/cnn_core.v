// Based of MATBI AIHW Course Project
// https://www.inflearn.com/course/%EC%8B%A4%EC%A0%84-%ED%95%98%EB%93%9C%EC%9B%A8%EC%96%B4-%EC%84%A4%EA%B3%84/dashboard

`include "timescale.vh"

module cnn_core(
    clk,
    reset_n,
    soft_reset_i,
    cnn_weight_i,
    cnn_bias_i,
    in_valid_i,
    in_fmap_i,
    ot_valid_o,
    ot_fmap_o
);
`include "defines_cnn_core.vh"

localparam LATENCY = 1;

input clk;
input reset_n;
input soft_reset_i;
input [CO*CI*KX*KY*W_BW-1:0] cnn_weight_i;
input [CO*B_BW-1:0] cnn_bias_i;
input in_valid_i;
input [CI*KX*KY*I_F_BW-1:0] in_fmap_i;
output ot_valid_o;
output [CO*O_F_BW-1:0] ot_fmap_o;

// enable signal shift
wire [LATENCY-1:0] ce;
reg [LATENCY-1:0] r_valid;
wire [CO-1:0] w_ot_valid;

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

// accumulate ci and get output for each co
wire [CO-1:0] w_in_valid;
wire [CO*(ACI_BW)-1:0] w_ot_ci_acc;

assign w_in_valid = {CO{in_valid_i}};

genvar co;
generate
    for (co = 0; co < CO; co=co+1) begin
        cnn_acc_ci u_cnn_acc_ci(
            .clk(clk),
            .reset_n(reset_n),
            .soft_reset_i(soft_reset_i),
            .in_valid_i(w_in_valid[co]),
            .cnn_weight_i(cnn_weight_i[co*CI*KX*KY*W_BW+:CI*KX*KY*W_BW]),
            .in_fmap_i(in_fmap_i[CI*KX*KY*I_F_BW-1:0]),
            .ot_valid_o(w_ot_valid[co]),
            .ot_ci_acc_o(w_ot_ci_acc[co*(ACI_BW)+:ACI_BW])
        );
    end
endgenerate

// add bias
wire [CO*AB_BW-1:0] add_bias;
reg [CO*AB_BW-1:0] r_add_bias;
genvar bias_idx;
for (bias_idx = 0; bias_idx < CO; bias_idx=bias_idx+1) begin

    assign add_bias[bias_idx*AB_BW+:AB_BW] = w_ot_ci_acc[bias_idx*(ACI_BW)+:ACI_BW] + cnn_bias_i[bias_idx*B_BW+:B_BW];

    always @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            r_add_bias[bias_idx*AB_BW+:AB_BW] <= {AB_BW{1'b0}};
        end else if (soft_reset_i) begin
            r_add_bias[bias_idx*AB_BW+:AB_BW] <= {AB_BW{1'b0}};
        end else if (&w_ot_valid) begin
            r_add_bias[bias_idx*AB_BW+:AB_BW] <= add_bias[bias_idx*AB_BW+:AB_BW];
        end
    end
end

// no activation function for this cnn_core
assign ot_valid_o = r_valid[LATENCY-1];
assign ot_fmap_o = r_add_bias;


endmodule