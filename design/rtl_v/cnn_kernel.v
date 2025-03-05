// Based of MATBI AIHW Course Project
// https://www.inflearn.com/course/%EC%8B%A4%EC%A0%84-%ED%95%98%EB%93%9C%EC%9B%A8%EC%96%B4-%EC%84%A4%EA%B3%84/dashboard

`include "timescale.vh"

module cnn_kernel (
    clk,
    reset_n,
    soft_reset_i,
    in_valid_i,
    cnn_weight_i,
    f_map_i,
    ot_valid_o,
    ot_kernel_acc_o
);
`include "defines_cnn_core.vh"
localparam LATENCY = 2;

input clk;
input reset_n;
input soft_reset_i;
input in_valid_i;
input [KX*KY*W_BW-1:0] cnn_weight_i;
input [KX*KY*I_F_BW-1:0] f_map_i;
output ot_valid_o;
output [O_F_BW-1:0] ot_kernel_acc_o;

// data vaild signal
wire [LATENCY-1:0] ce;
reg [LATENCY-1:0] r_valid;
always @ (posedge clk or negedge reset_n) begin
    if (!reset_n) begin
        r_valid <= {LATENCY{1'b0}};
    end else if (soft_reset_i) begin
        r_valid <= {LATENCY{1'b0}};
    end else begin
        r_valid <= {r_valid[LATENCY-2:0], in_valid_i};
    end
end

assign ce = r_valid;

// multiplication of fmap * weight 
reg [KX*KY*M_BW-1:0] r_mul;

// multiply each kernels
integer mul_x_idx;
integer mul_y_idx;
generate
    always @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            r_mul <= {KX*KY*M_BW{1'b0}};
        end else if (soft_reset_i) begin
            r_mul <= {KX*KY*M_BW{1'b0}};
        end else if (in_valid_i) begin
            for (mul_x_idx = 0; mul_x_idx < KX; mul_x_idx=mul_x_idx+1) begin
                for (mul_y_idx = 0; mul_y_idx < KY; mul_y_idx=mul_y_idx+1) begin
                    r_mul[((KY*mul_x_idx)+mul_y_idx)*M_BW+:M_BW] <= f_map_i[((KY*mul_x_idx)+mul_y_idx)*I_F_BW+:I_F_BW] * cnn_weight_i[((KY*mul_x_idx)+mul_y_idx)*W_BW+:W_BW];
                end
            end            
        end
    end
endgenerate

assign mul = r_mul;

// accumulation
reg [AK_BW-1:0] w_acc_kernel; // temp for always (*)
reg [AK_BW-1:0] r_acc_kernel;
integer acc_x_idx;
integer acc_y_idx;
generate
    always @ (*) begin
        w_acc_kernel[AK_BW-1:0] = {AK_BW{1'b0}};
        for (acc_x_idx = 0; acc_x_idx < KX; acc_x_idx=acc_x_idx+1) begin
            for (acc_y_idx = 0; acc_y_idx < KY; acc_y_idx=acc_y_idx+1) begin
                w_acc_kernel[AK_BW-1:0] = w_acc_kernel[AK_BW-1:0] + r_mul[((KY*acc_x_idx)+acc_y_idx)*M_BW+:M_BW];
            end
        end        
    end

    always @ (posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            r_acc_kernel[AK_BW-1:0] <= {AK_BW{1'b0}};
        end else if (soft_reset_i) begin
            r_acc_kernel[AK_BW-1:0] <= {AK_BW{1'b0}};
        end else if (ce[LATENCY-2]) begin
            r_acc_kernel[AK_BW-1:0] <= w_acc_kernel[AK_BW-1:0];
        end
    end
endgenerate

assign ot_valid_o = r_valid[LATENCY-1];
assign ot_kernel_acc_o = r_acc_kernel;

endmodule