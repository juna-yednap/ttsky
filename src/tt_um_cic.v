/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */


module tt_um_cic #(
	parameter integer out_width = 7,
	parameter integer in_width = 4,
	parameter integer decimation_ratio = 8,
	parameter integer order = 6,
	parameter integer differential_delay = 4
) (
	input  wire						 ena,
	input  wire                      clk,
	input  wire                      rst,
	input  signed [in_width-1:0]     d_in,
	input  wire                      valid_in,
	output wire                      valid_out,
	output wire  signed [out_width-1:0]   d_out
);

localparam integer COUNTW = $clog2(decimation_ratio);
localparam integer GAIN_BITS = order * $clog2(decimation_ratio * differential_delay);
reg signed [in_width+GAIN_BITS-1:0] d_tmp;
reg signed [in_width+GAIN_BITS-1:0] integrator [0:order-1];

reg [COUNTW-1 : 0] counter;
always@(negedge clk or posedge rst) begin
    if(rst) counter <= {COUNTW{1'b1}};
    else if(valid_in) begin
        counter<=counter+1;
    end
end
assign valid_out = ((counter == 1'b0));
wire signed [in_width+GAIN_BITS-1:0] comb [0:order-1];
reg signed [in_width+GAIN_BITS-1:0] d_comb [0:order-1][0:differential_delay-1];
reg d_clk_tmp;
integer i;
integer j;
// Integrator + decimation control
always @(posedge clk or posedge rst) begin
	if (rst) begin
		for (i = 0; i <= order-1; i = i + 1) begin
			integrator[i] <= {(in_width+GAIN_BITS-1){1'b0}};
		end
		d_tmp <= {(in_width+GAIN_BITS-1){1'b0}};
	end else if(valid_in) begin
		integrator[0] <= integrator[0] + $signed(d_in);
		for(i = 1; i <= order-1; i = i + 1) begin
			integrator[i] <= integrator[i] + integrator[i-1];
		end
		// Decimation control: when valid_out enabled capture output
		if (valid_out ) begin
			d_tmp <= integrator[order-1];
		end
	end
end
// Comb section (processes one decimated sample when valid_out is asserted)
always @(posedge clk or posedge rst) begin
	if (rst) begin
	    for (i = 0; i <= order-1; i = i + 1) begin
	        for (j = 0; j < differential_delay; j = j + 1) begin
	                d_comb[i][j] <= {(in_width+GAIN_BITS-1){1'b0}};
	            end
	        end
	    end else begin
	        if (valid_out)  begin
	            for (j = differential_delay-1; j > 0; j = j - 1) begin
	                d_comb[0][j] <= d_comb[0][j-1];
	            end
	            d_comb[0][0] <= d_tmp;
					
	            for (i = 1; i <= order-1; i = i + 1) begin
	               for (j = differential_delay-1; j > 0; j = j - 1) begin
	                    d_comb[i][j] <= d_comb[i][j-1];
	                end
	                d_comb[i][0] <= comb[i-1];
	            end
	        end
	    end
end
genvar r;
assign comb[0] = d_tmp - d_comb[0][differential_delay-1];
generate
	for (r=1; r<order; r=r+1) begin: hello
		assign comb[r] = comb[r-1] - d_comb[r][differential_delay-1];
	end
endgenerate
assign d_out =
    ( comb[order-1] + (1 << (in_width+GAIN_BITS-out_width-1)) )
    >>> (in_width+GAIN_BITS-out_width);
endmodule
