`timescale 1ns/1ps
module QR_Engine (
    i_clk,
    i_rst,
    i_trig,
    i_data,
    o_rd_vld,
    o_last_data,
    o_y_hat,
    o_r
);

// IO description
input          i_clk;
input          i_rst;
input          i_trig;
input  [ 47:0] i_data;
output reg        o_rd_vld;
output reg        o_last_data;
output [159:0] o_y_hat;
output [319:0] o_r;

parameter IDLE = 1'b0;
parameter RUN = 1'b1;
reg state,state_nxt;

integer i,j;

//COUNT
reg [2:0] cnt,cnt_nxt;
reg [1:0] iteration_cnt,iteration_cnt_nxt;
reg [3:0] round_cnt, round_cnt_nxt;

//REG
reg [31:0] H[0:3][0:3],H_nxt[0:3][0:3],H_backup[0:3][0:3],H_backup_nxt[0:3][0:3];
reg [31:0] unit_vector[0:3][0:3], unit_vector_nxt[0:3][0:3];
reg [31:0] Y[0:3], Y_nxt[0:3],Y_backup[0:3], Y_backup_nxt[0:3];
reg signed[39:0] Rij[0:5],Rij_nxt[0:5];
reg signed[19:0] Rii[0:3],Rii_nxt[0:3];
reg signed [39:0] y_sum[0:3],y_sum_nxt[0:3];

//OUTPUT
reg out_yes, out_yes_nxt;
/*
assign o_rd_vld = rd_vld;
assign o_last_data = last_data;
*/

reg [319:0] r_output,r_output_nxt;
reg [159:0] y_output,y_output_nxt;
assign o_r =  r_output;
assign o_y_hat = y_output;

//ADD
reg [19:0] add_in[0:1][0:3];
reg [19:0] add_in2[0:3];
wire [21:0] adder_out[0:2];
wire [20:0] mid_sum1[0:2], mid_sum2[0:2];
//MULT
reg [11:0] a_real[0:1][0:3], a_img[0:1][0:3], b_real[0:1][0:3], b_img[0:1][0:3], a_real2, a_img2, b_real2, b_img2;
wire [24:0] mult_out_img[0:1][0:3], mult_out_real[0:1][0:3], mult_out_img2, mult_out_real2;

//SQRT
reg [13:0] sqrt_in; //4.10
wire [18:0] sqrt_out; //3.16
reg [10:0] distance,distance_nxt;
wire [10:0] inv_sqrt_out; //3.8

//ADD REG
reg [32:0] temp_out_real[0:1][0:3], temp_out_real_nxt[0:1][0:3],temp_out_img[0:1][0:3], temp_out_img_nxt[0:1][0:3],temp_out_img2, temp_out_img2_nxt,temp_out_real2, temp_out_real2_nxt;

////////////////////////////////////////////

always @(*)begin

    o_rd_vld = (iteration_cnt == 1 & cnt == 1 & out_yes); 
    o_last_data = ( (round_cnt == 9) & (iteration_cnt == 3) & (cnt == 4) );
    
    r_output_nxt = r_output;
    y_output_nxt = y_output;
    state_nxt = state;
    cnt_nxt = (cnt == 4)? 0 : cnt + 1;
    iteration_cnt_nxt = (cnt == 4)? iteration_cnt + 1 : iteration_cnt;
    distance_nxt = distance;
    
    if ( (iteration_cnt == 3) & (cnt == 4) ) 
        if(round_cnt == 9) round_cnt_nxt = 0;
        else round_cnt_nxt = round_cnt + 1;
    else round_cnt_nxt = round_cnt;

    for(i = 0; i < 4 ; i = i + 1)begin
        Rii_nxt[i] = Rii[i];
        add_in2[i] = 0;
    end
    for(i = 0; i < 6 ; i = i + 1)begin
        Rij_nxt[i] =  Rij[i];
    end

    for(i = 0; i < 4 ; i = i + 1)begin
        for(j = 0; j < 4 ; j = j + 1)begin
            H_nxt[i][j] = H[i][j];
            H_backup_nxt[i][j] = H_backup[i][j];
            unit_vector_nxt[i][j] = unit_vector[i][j];
        end
        Y_nxt[i] = Y[i];
        y_sum_nxt[i] = y_sum[i];
        Y_backup_nxt[i] = Y_backup[i];
    end
    
    for(i = 0; i < 2 ; i = i + 1)begin
        for(j = 0; j < 4 ; j = j + 1)begin
            a_real[i][j] = 0;
            a_img[i][j] = 0;
            b_real[i][j] = 0;
            b_img[i][j] = 0;
            add_in[i][j] = 0;
            temp_out_real_nxt[i][j] = temp_out_real[i][j];
            temp_out_img_nxt[i][j] = temp_out_img[i][j];
        end
    end
    temp_out_img2_nxt = temp_out_img2;
    temp_out_real2_nxt = temp_out_real2;
    a_real2 = 0;
    a_img2 = 0;
    b_real2 = 0;
    b_img2 = 0;
    sqrt_in = 0;

    //
    out_yes_nxt = out_yes | round_cnt == 2 ;
    
    //Y
    case(iteration_cnt)
        2'd0:begin
            case(cnt)
                0:begin
                //inv sqrt 4
                    add_in2[0] = mult_out_img[1][0][23:10];
                    add_in2[1] = mult_out_img[1][1][23:10];
                    add_in2[2] = mult_out_img[1][2][23:10];
                    add_in2[3] = mult_out_img[1][3][23:10];
                    sqrt_in = adder_out[2];
                    distance_nxt = inv_sqrt_out;

                //R44
                    Rii_nxt[3] = sqrt_out;
                    
                //R12 ADD
                    add_in[0][0] = mult_out_real[0][0][24:5];
                    add_in[0][1] = mult_out_real[0][1][24:5];
                    add_in[0][2] = mult_out_real[0][2][24:5];
                    add_in[0][3] = mult_out_real[0][3][24:5];
                    
                    add_in[1][0] = mult_out_img[0][0][24:5];
                    add_in[1][1] = mult_out_img[0][1][24:5];
                    add_in[1][2] = mult_out_img[0][2][24:5];
                    add_in[1][3] = mult_out_img[0][3][24:5];
                    
                    Rij_nxt[0][39:20] = adder_out[1];
                    Rij_nxt[0][19:0] = adder_out[0];

                //R13 MUL
                    a_real[0][0] = H[0][2][15:4];
                    a_img[0][0] =  H[0][2][31:20];
                    b_real[0][0] = unit_vector[0][0][15:4];
                    b_img[0][0] = ~unit_vector[0][0][31:20] ;

                    a_real[0][1] = H[1][2][15:4];
                    a_img[0][1] =  H[1][2][31:20];
                    b_real[0][1] = unit_vector[0][1][15:4];
                    b_img[0][1] = ~unit_vector[0][1][31:20] ;

                    a_real[0][2] = H[2][2][15:4];
                    a_img[0][2] =  H[2][2][31:20];
                    b_real[0][2] = unit_vector[0][2][15:4];
                    b_img[0][2] = ~unit_vector[0][2][31:20] ;

                    a_real[0][3] = H[3][2][15:4];
                    a_img[0][3] =  H[3][2][31:20];
                    b_real[0][3] = unit_vector[0][3][15:4];
                    b_img[0][3] = ~unit_vector[0][3][31:20] ;

                    end
                1:begin
                //Q4 Mul
                    a_real[0][0] = {1'b0,distance};
                    b_real[0][0] = H[0][3][15:4];
                    b_img[0][0] = H[0][3][31:20];
                    
                    a_real[0][1] = {1'b0,distance};
                    b_real[0][1] = H[1][3][15:4];
                    b_img[0][1] = H[1][3][31:20];
                    
                    a_real[0][2] = {1'b0,distance};
                    b_real[0][2] = H[2][3][15:4];
                    b_img[0][2] = H[2][3][31:20];
                    
                    a_real[0][3] = {1'b0,distance};
                    b_real[0][3] = H[3][3][15:4];
                    b_img[0][3] = H[3][3][31:20];

                //R13 ADD
                    add_in[0][0] = mult_out_real[0][0][24:5];
                    add_in[0][1] = mult_out_real[0][1][24:5];
                    add_in[0][2] = mult_out_real[0][2][24:5];
                    add_in[0][3] = mult_out_real[0][3][24:5];
                    
                    add_in[1][0] = mult_out_img[0][0][24:5];
                    add_in[1][1] = mult_out_img[0][1][24:5];
                    add_in[1][2] = mult_out_img[0][2][24:5];
                    add_in[1][3] = mult_out_img[0][3][24:5];
                    
                    Rij_nxt[1][39:20] = adder_out[1];
                    Rij_nxt[1][19:0] = adder_out[0];

                end
                2:begin
                //Q4 Add
                    unit_vector_nxt[3][0] = {mult_out_img[0][0][18:3],mult_out_real[0][0][18:3]};
                    unit_vector_nxt[3][1] = {mult_out_img[0][1][18:3],mult_out_real[0][1][18:3]};
                    unit_vector_nxt[3][2] = {mult_out_img[0][2][18:3],mult_out_real[0][2][18:3]};
                    unit_vector_nxt[3][3] = {mult_out_img[0][3][18:3],mult_out_real[0][3][18:3]};

                //R14 MUL
                    a_real[0][0] = H[0][3][15:4];
                    a_img[0][0] =  H[0][3][31:20];
                    b_real[0][0] = unit_vector[0][0][15:4];
                    b_img[0][0] = ~unit_vector[0][0][31:20];

                    a_real[0][1] = H[1][3][15:4];
                    a_img[0][1] =  H[1][3][31:20];
                    b_real[0][1] = unit_vector[0][1][15:4];
                    b_img[0][1] = ~unit_vector[0][1][31:20];

                    a_real[0][2] = H[2][3][15:4];
                    a_img[0][2] =  H[2][3][31:20];
                    b_real[0][2] = unit_vector[0][2][15:4];
                    b_img[0][2] = ~unit_vector[0][2][31:20];

                    a_real[0][3] = H[3][3][15:4];
                    a_img[0][3] =  H[3][3][31:20];
                    b_real[0][3] = unit_vector[0][3][15:4];
                    b_img[0][3] = ~unit_vector[0][3][31:20]; 

                end
                3:begin
                //R14 ADD
                    add_in[0][0] = mult_out_real[0][0][24:5];
                    add_in[0][1] = mult_out_real[0][1][24:5];
                    add_in[0][2] = mult_out_real[0][2][24:5];
                    add_in[0][3] = mult_out_real[0][3][24:5];;
                    
                    add_in[1][0] = mult_out_img[0][0][24:5];
                    add_in[1][1] = mult_out_img[0][1][24:5];
                    add_in[1][2] = mult_out_img[0][2][24:5];
                    add_in[1][3] = mult_out_img[0][3][24:5];
                    
                    Rij_nxt[2][39:20] = adder_out[1];
                    Rij_nxt[2][19:0] = adder_out[0];

                //square 2  MUl
                    a_real[0][0] = H[0][1][15:4];
                    a_img[0][0] = H[0][1][31:20];
                    b_real[0][0] = H[0][1][31:20];
                    b_img[0][0] =  H[0][1][15:4];
                    
                    a_real[0][1] = H[1][1][15:4];
                    a_img[0][1] = H[1][1][31:20];
                    b_real[0][1] = H[1][1][31:20];
                    b_img[0][1] =  H[1][1][15:4];
                    
                    a_real[0][2] = H[2][1][15:4];
                    a_img[0][2] = H[2][1][31:20];
                    b_real[0][2] = H[2][1][31:20];
                    b_img[0][2] =  H[2][1][15:4];
                    
                    a_real[0][3] = H[3][1][15:4];
                    a_img[0][3] = H[3][1][31:20];
                    b_real[0][3] = H[3][1][31:20];
                    b_img[0][3] =  H[3][1][15:4];
                    
                //Y4  Mul
                    a_real[1][0] = unit_vector[3][0][15:4];
                    b_real[1][0] = Y[0][15:4];
                    a_img[1][0] = ~unit_vector[3][0][31:20] ;
                    b_img[1][0] = Y[0][31:20];
                    
                    a_real[1][1] = unit_vector[3][1][15:4];
                    b_real[1][1] = Y[1][15:4];
                    a_img[1][1] = ~unit_vector[3][1][31:20] ;
                    b_img[1][1] = Y[1][31:20];

                    a_real[1][2] = unit_vector[3][2][15:4];
                    b_real[1][2] = Y[2][15:4];
                    a_img[1][2] = ~unit_vector[3][2][31:20] ;
                    b_img[1][2] = Y[2][31:20];

                    a_real[1][3] = unit_vector[3][3][15:4];
                    b_real[1][3] = Y[3][15:4];
                    a_img[1][3] = ~unit_vector[3][3][31:20] ;
                    b_img[1][3] = Y[3][31:20];
                   
                end
                4:begin
                //inv sqrt 2
                    add_in[0][0] = mult_out_img[0][0][23:10];
                    add_in[0][1] = mult_out_img[0][1][23:10];
                    add_in[0][2] = mult_out_img[0][2][23:10];
                    add_in[0][3] = mult_out_img[0][3][23:10];
                    sqrt_in = adder_out[0];
                    distance_nxt = inv_sqrt_out;
                
                //R22
                    Rii_nxt[1] = sqrt_out;
                
                //Y11 MUl
                    a_real2 = unit_vector[0][0][15:4];
                    b_real2 = Y[0][15:4];
                    a_img2 = ~unit_vector[0][0][31:20] ;
                    b_img2 = Y[0][31:20];
                
                //Y4 Add 

                    add_in[1][0] = mult_out_real[1][0][24:5];
                    add_in[1][1] = mult_out_real[1][1][24:5];
                    add_in[1][2] = mult_out_real[1][2][24:5];
                    add_in[1][3] = mult_out_real[1][3][24:5];

                    add_in2[0] = mult_out_img[1][0][24:5];
                    add_in2[1] = mult_out_img[1][1][24:5];
                    add_in2[2] = mult_out_img[1][2][24:5];
                    add_in2[3] = mult_out_img[1][3][24:5];
            
                    y_sum_nxt[3] = {adder_out[2][19:0],adder_out[1][19:0]};
                    
                end
            endcase
        end
        2'd1:begin
            case(cnt)
                
                0:begin
                //Q2 Mul
                    a_real[0][0] = {1'b0,distance};
                    b_real[0][0] = H[0][1][15:4];
                    b_img[0][0] = H[0][1][31:20];  
                    
                    a_real[0][1] = {1'b0,distance};
                    b_real[0][1] = H[1][1][15:4];
                    b_img[0][1] = H[1][1][31:20];
                    
                    a_real[0][2] = {1'b0,distance};
                    b_real[0][2] = H[2][1][15:4];
                    b_img[0][2] = H[2][1][31:20];
                    
                    a_real[0][3] = {1'b0,distance};
                    b_real[0][3] = H[3][1][15:4];
                    b_img[0][3] = H[3][1][31:20];
                   
                //Y11 Add
                    y_sum_nxt[0] = {mult_out_img2[24:5],mult_out_real2[24:5]} ;
                
                //Y21 Mul
                    a_real2 = unit_vector[0][1][15:4];
                    b_real2 = Y[1][15:4];
                    a_img2 = ~unit_vector[0][1][31:20] ;
                    b_img2 = Y[1][31:20];
                        
                end
                1:begin
                //Q2 Add
                    unit_vector_nxt[1][0] = {mult_out_img[0][0][18:3],mult_out_real[0][0][18:3]};
                    unit_vector_nxt[1][1] = {mult_out_img[0][1][18:3],mult_out_real[0][1][18:3]};
                    unit_vector_nxt[1][2] = {mult_out_img[0][2][18:3],mult_out_real[0][2][18:3]};
                    unit_vector_nxt[1][3] = {mult_out_img[0][3][18:3],mult_out_real[0][3][18:3]};
             
                //Y21 Add
                    add_in[1][0] = mult_out_real2[24:5];
                    add_in[1][1] = y_sum[0][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[0][39:20];

                    y_sum_nxt[0] = {adder_out[2][19:0],adder_out[1][19:0]};

                //Y31 Mul
                    a_real2 = unit_vector[0][2][15:4];
                    b_real2 = Y[2][15:4];
                    a_img2 = ~unit_vector[0][2][31:20] ;
                    b_img2 = Y[2][31:20];
                
                end
                2:begin
                //R23 Mul
                    a_real[0][0] = H[0][2][15:4];
                    a_img[0][0] =  H[0][2][31:20];
                    b_real[0][0] = unit_vector[1][0][15:4];
                    b_img[0][0] = ~unit_vector[1][0][31:20] ;

                    a_real[0][1] = H[1][2][15:4];
                    a_img[0][1] =  H[1][2][31:20];
                    b_real[0][1] = unit_vector[1][1][15:4];
                    b_img[0][1] = ~unit_vector[1][1][31:20] ;

                    a_real[0][2] = H[2][2][15:4];
                    a_img[0][2] =  H[2][2][31:20];
                    b_real[0][2] = unit_vector[1][2][15:4];
                    b_img[0][2] = ~unit_vector[1][2][31:20] ;

                    a_real[0][3] = H[3][2][15:4];
                    a_img[0][3] =  H[3][2][31:20];
                    b_real[0][3] = unit_vector[1][3][15:4];
                    b_img[0][3] = ~unit_vector[1][3][31:20] ;
  
                //Y31 Add  

                    add_in[1][0] = mult_out_real2[24:5];
                    add_in[1][1] = y_sum[0][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[0][39:20];
                    
                    y_sum_nxt[0] = {adder_out[2][19:0],adder_out[1][19:0]};

                //Y41 Mul
                    a_real2 = unit_vector[0][3][15:4];
                    b_real2 = Y[3][15:4];
                    a_img2 = ~unit_vector[0][3][31:20] ;
                    b_img2 = Y[3][31:20];      
                    
                end
                3:begin
                //R23 ADD
                    add_in[0][0] = mult_out_real[0][0][24:5];
                    add_in[0][1] = mult_out_real[0][1][24:5];
                    add_in[0][2] = mult_out_real[0][2][24:5];
                    add_in[0][3] = mult_out_real[0][3][24:5];
                    
                    add_in[1][0] = mult_out_img[0][0][24:5];
                    add_in[1][1] = mult_out_img[0][1][24:5];
                    add_in[1][2] = mult_out_img[0][2][24:5];
                    add_in[1][3] = mult_out_img[0][3][24:5];
                    
                    Rij_nxt[3][39:20] = adder_out[1];
                    Rij_nxt[3][19:0] = adder_out[0];

                //R24 Mul
                    a_real[0][0] = H[0][3][15:4];
                    a_img[0][0] =  H[0][3][31:20];
                    b_real[0][0] = unit_vector[1][0][15:4];
                    b_img[0][0] = ~unit_vector[1][0][31:20] ;

                    a_real[0][1] = H[1][3][15:4];
                    a_img[0][1] =  H[1][3][31:20];
                    b_real[0][1] = unit_vector[1][1][15:4];
                    b_img[0][1] = ~unit_vector[1][1][31:20] ;

                    a_real[0][2] = H[2][3][15:4];
                    a_img[0][2] =  H[2][3][31:20];
                    b_real[0][2] = unit_vector[1][2][15:4];
                    b_img[0][2] = ~unit_vector[1][2][31:20] ;

                    a_real[0][3] = H[3][3][15:4];
                    a_img[0][3] =  H[3][3][31:20];
                    b_real[0][3] = unit_vector[1][3][15:4];
                    b_img[0][3] = ~unit_vector[1][3][31:20] ;


                //Y41 Add 

                    add_in2[2] = mult_out_real2[24:5];
                    add_in2[3] = y_sum[0][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[0][39:20];
                    
                    y_sum_nxt[0] = {mid_sum1[2][19:0],mid_sum2[2][19:0]};

                //Y12 Mul
                    a_real2 = unit_vector[1][0][15:4];
                    b_real2 = Y[0][15:4];
                    a_img2 = ~unit_vector[1][0][31:20] ;
                    b_img2 = Y[0][31:20];
    
                end 
                4:begin
                //R24 Add
                    add_in[0][0] = mult_out_real[0][0][24:5];
                    add_in[0][1] = mult_out_real[0][1][24:5];
                    add_in[0][2] = mult_out_real[0][2][24:5];
                    add_in[0][3] = mult_out_real[0][3][24:5];
                    
                    add_in[1][0] = mult_out_img[0][0][24:5];
                    add_in[1][1] = mult_out_img[0][1][24:5];
                    add_in[1][2] = mult_out_img[0][2][24:5];
                    add_in[1][3] = mult_out_img[0][3][24:5];
                    
                    Rij_nxt[4][39:20] = adder_out[1];
                    Rij_nxt[4][19:0] = adder_out[0];  

                //Y12 Add
                    y_sum_nxt[1] = {mult_out_img2[24:5],mult_out_real2[24:5]};

                //Y22 Mul
                    a_real2 = unit_vector[1][1][15:4];
                    b_real2 = Y[1][15:4];
                    a_img2 = ~unit_vector[1][1][31:20] ;
                    b_img2 = Y[1][31:20];

                end
            endcase
        end
        2'd2:begin
            case(cnt)
                0:begin
                //Y22 Add

                    add_in2[2] = mult_out_real2[24:5];
                    add_in2[3] = y_sum[1][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[1][39:20];
                    
                    y_sum_nxt[1] = {mid_sum1[2][19:0],mid_sum2[2][19:0]};

                //Y32 Mul
                    a_real2 = unit_vector[1][2][15:4];
                    b_real2 = Y[2][15:4];
                    a_img2 = ~unit_vector[1][2][31:20] ;
                    b_img2 = Y[2][31:20];    
                    
                end
                1:begin
                //square 3 Mul
                    a_real[0][0] = H[0][2][15:4];
                    a_img[0][0] = H[0][2][31:20];
                    b_real[0][0] = H[0][2][31:20];
                    b_img[0][0] =  H[0][2][15:4];
                    
                    a_real[0][1] = H[1][2][15:4];
                    a_img[0][1] = H[1][2][31:20];
                    b_real[0][1] = H[1][2][31:20];
                    b_img[0][1] =  H[1][2][15:4];
                    
                    a_real[0][2] = H[2][2][15:4];
                    a_img[0][2] = H[2][2][31:20];
                    b_real[0][2] = H[2][2][31:20];
                    b_img[0][2] =  H[2][2][15:4];
                    
                    a_real[0][3] = H[3][2][15:4];
                    a_img[0][3] = H[3][2][31:20];
                    b_real[0][3] = H[3][2][31:20];
                    b_img[0][3] =  H[3][2][15:4];      
                    
                //Y32 Add 

                    add_in2[2] = mult_out_real2[24:5];
                    add_in2[3] = y_sum[1][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[1][39:20];
                    
                    y_sum_nxt[1] = {mid_sum1[2][19:0],mid_sum2[2][19:0]};

                //Y42 Mul
                    a_real2 = unit_vector[1][3][15:4];
                    b_real2 = Y[3][15:4];
                    a_img2 = ~unit_vector[1][3][31:20] ;
                    b_img2 = Y[3][31:20]; 
                    
                end 
                2:begin
                //inv sqrt 3
                    add_in[0][0] = mult_out_img[0][0][23:10];
                    add_in[0][1] = mult_out_img[0][1][23:10];
                    add_in[0][2] = mult_out_img[0][2][23:10];
                    add_in[0][3] = mult_out_img[0][3][23:10];
                    sqrt_in = adder_out[0];
                    distance_nxt = inv_sqrt_out;                   
                
                //R33
                    Rii_nxt[2] = sqrt_out;    
                //Y42 Add
                    add_in[1][0] = mult_out_real2[24:5];
                    add_in[1][1] = y_sum[1][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[1][39:20];
                    
                    y_sum_nxt[1] = {adder_out[2][19:0],adder_out[1][19:0]};
                    
                end
                3:begin
                //Q3 Mul
                    a_real[0][0] = {1'b0,distance};
                    b_real[0][0] = H[0][2][15:4];
                    b_img[0][0] = H[0][2][31:20];
                    
                    a_real[0][1] = {1'b0,distance};
                    b_real[0][1] = H[1][2][15:4];
                    b_img[0][1] = H[1][2][31:20];    

                    a_real[0][2] = {1'b0,distance};
                    b_real[0][2] = H[2][2][15:4];
                    b_img[0][2] = H[2][2][31:20];
                    
                    a_real[0][3] = {1'b0,distance};
                    b_real[0][3] = H[3][2][15:4];
                    b_img[0][3] = H[3][2][31:20];
                     
                end
                4:begin
                //Q3 Add
                    unit_vector_nxt[2][0] = {mult_out_img[0][0][18:3],mult_out_real[0][0][18:3]};
                    unit_vector_nxt[2][1] = {mult_out_img[0][1][18:3],mult_out_real[0][1][18:3]};
                    unit_vector_nxt[2][2] = {mult_out_img[0][2][18:3],mult_out_real[0][2][18:3]};
                    unit_vector_nxt[2][3] = {mult_out_img[0][3][18:3],mult_out_real[0][3][18:3]};
  
                end
            
            endcase
        end
        2'd3:begin
            case(cnt)
                0:begin
                //R34 Mul
                    a_real[1][0] = H[0][3][15:4];
                    a_img[1][0] =  H[0][3][31:20];
                    b_real[1][0] = unit_vector[2][0][15:4];
                    b_img[1][0] = ~unit_vector[2][0][31:20] ;

                    a_real[1][1] = H[1][3][15:4];
                    a_img[1][1] =  H[1][3][31:20];
                    b_real[1][1] = unit_vector[2][1][15:4];
                    b_img[1][1] = ~unit_vector[2][1][31:20] ;

                    a_real[1][2] = H[2][3][15:4];
                    a_img[1][2] =  H[2][3][31:20];
                    b_real[1][2] = unit_vector[2][2][15:4];
                    b_img[1][2] = ~unit_vector[2][2][31:20] ;

                    a_real[1][3] = H[3][3][15:4];
                    a_img[1][3] =  H[3][3][31:20];
                    b_real[1][3] = unit_vector[2][3][15:4];
                    b_img[1][3] = ~unit_vector[2][3][31:20] ;
                    
                //square 1 Mul
                    a_real[0][0] = H_backup[0][0][15:4];
                    a_img[0][0] = H_backup[0][0][31:20];
                    b_real[0][0] = H_backup[0][0][31:20];
                    b_img[0][0] =  H_backup[0][0][15:4];
                    
                    a_real[0][1] = H_backup[1][0][15:4];
                    a_img[0][1] = H_backup[1][0][31:20];
                    b_real[0][1] = H_backup[1][0][31:20];
                    b_img[0][1] =  H_backup[1][0][15:4];
                    
                    a_real[0][2] = H_backup[2][0][15:4];
                    a_img[0][2] = H_backup[2][0][31:20];
                    b_real[0][2] = H_backup[2][0][31:20];
                    b_img[0][2] =  H_backup[2][0][15:4];
                    
                    a_real[0][3] = i_data[23:12];
                    a_img[0][3] =  i_data[47:36];
                    b_real[0][3] = i_data[47:36];
                    b_img[0][3] =  i_data[23:12];

                //Y13 Mul
                    a_real2 = unit_vector[2][0][15:4];
                    b_real2 = Y[0][15:4];
                    a_img2 = ~unit_vector[2][0][31:20] ;
                    b_img2 = Y[0][31:20];
                
                end
                1:begin
                //R34 Add
                    add_in[1][0] = mult_out_real[1][0][24:5];
                    add_in[1][1] = mult_out_real[1][1][24:5];
                    add_in[1][2] = mult_out_real[1][2][24:5];
                    add_in[1][3] = mult_out_real[1][3][24:5];
                    
                    add_in2[0] = mult_out_img[1][0][24:5];
                    add_in2[1] = mult_out_img[1][1][24:5];
                    add_in2[2] = mult_out_img[1][2][24:5];
                    add_in2[3] = mult_out_img[1][3][24:5];
                    
                    Rij_nxt[5][39:20] = adder_out[2];
                    Rij_nxt[5][19:0] = adder_out[1];

                //inv sqrt 1
                    add_in[0][0] = mult_out_img[0][0][23:10];
                    add_in[0][1] = mult_out_img[0][1][23:10];
                    add_in[0][2] = mult_out_img[0][2][23:10];
                    add_in[0][3] = mult_out_img[0][3][23:10];
                    sqrt_in = adder_out[0];
                    distance_nxt = inv_sqrt_out;
                //R11
                    Rii_nxt[0] = sqrt_out;

                //Y13 Add
                    y_sum_nxt[2] = {mult_out_img2[24:5],mult_out_real2[24:5]};
                
                //Y23 Mul
                    a_real2 = unit_vector[2][1][15:4];
                    b_real2 = Y[1][15:4];
                    a_img2 = ~unit_vector[2][1][31:20] ;
                    b_img2 = Y[1][31:20];  
                    
                end
                2:begin
                    
                //Q1 Mul
                    a_real[0][0] = {1'b0,distance};
                    b_real[0][0] = H_backup[0][0][15:4];
                    b_img[0][0] = H_backup[0][0][31:20];
                    
                    a_real[0][1] = {1'b0,distance};
                    b_real[0][1] = H_backup[1][0][15:4];
                    b_img[0][1] = H_backup[1][0][31:20];

                    a_real[0][2] = {1'b0,distance};
                    b_real[0][2] = H_backup[2][0][15:4];
                    b_img[0][2] = H_backup[2][0][31:20];
                    
                    a_real[0][3] = {1'b0,distance};
                    b_real[0][3] = H_backup[3][0][15:4];
                    b_img[0][3] = H_backup[3][0][31:20];

                //Y23 Add //EMILY

                    add_in[1][0] = mult_out_real2[24:5];
                    add_in[1][1] = y_sum[2][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[2][39:20];
                    
                    y_sum_nxt[2] = {adder_out[2][19:0],adder_out[1][19:0]};

                //Y33 Mul
                    a_real2 = unit_vector[2][2][15:4];
                    b_real2 = Y[2][15:4];
                    a_img2 = ~unit_vector[2][2][31:20] ;
                    b_img2 = Y[2][31:20]; 
                    
                end
                3:begin
                //Q1 Add
                    unit_vector_nxt[0][0] = {mult_out_img[0][0][18:3],mult_out_real[0][0][18:3]};
                    unit_vector_nxt[0][1] = {mult_out_img[0][1][18:3],mult_out_real[0][1][18:3]};
                    unit_vector_nxt[0][2] = {mult_out_img[0][2][18:3],mult_out_real[0][2][18:3]};
                    unit_vector_nxt[0][3] = {mult_out_img[0][3][18:3],mult_out_real[0][3][18:3]};

                //Y33 Add

                    add_in2[2] = mult_out_real2[24:5];
                    add_in2[3] = y_sum[2][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[2][39:20];
                    
                    y_sum_nxt[2] = {mid_sum1[2][19:0],mid_sum2[2][19:0]};
                
                //Y43 Mul
                        a_real2 = unit_vector[2][3][15:4];
                        b_real2 = Y[3][15:4];
                        a_img2 = ~unit_vector[2][3][31:20] ;
                        b_img2 = Y[3][31:20]; 
                end
                4:begin
                //square 4 Mul
                    a_real[1][0] = H[0][3][15:4];
                    a_img[1][0] = H[0][3][31:20];
                    b_real[1][0] = H[0][3][31:20];
                    b_img[1][0] =  H[0][3][15:4];
                    
                    a_real[1][1] = H[1][3][15:4];
                    a_img[1][1] = H[1][3][31:20];
                    b_real[1][1] = H[1][3][31:20];
                    b_img[1][1] =  H[1][3][15:4];
                    
                    a_real[1][2] = H[2][3][15:4];
                    a_img[1][2] = H[2][3][31:20];
                    b_real[1][2] = H[2][3][31:20];
                    b_img[1][2] =  H[2][3][15:4];
                    
                    a_real[1][3] = H[3][3][15:4];
                    a_img[1][3] = H[3][3][31:20];
                    b_real[1][3] = H[3][3][31:20];
                    b_img[1][3] =  H[3][3][15:4];
                
                //R12 MUL
                    a_real[0][0] = H_backup[0][1][15:4];
                    a_img[0][0] =  H_backup[0][1][31:20];
                    b_real[0][0] = unit_vector[0][0][15:4];
                    b_img[0][0] = ~unit_vector[0][0][31:20] ;

                    a_real[0][1] = H_backup[1][1][15:4];
                    a_img[0][1] =  H_backup[1][1][31:20];
                    b_real[0][1] = unit_vector[0][1][15:4];
                    b_img[0][1] = ~unit_vector[0][1][31:20] ;

                    a_real[0][2] = H_backup[2][1][15:4];
                    a_img[0][2] =  H_backup[2][1][31:20];
                    b_real[0][2] = unit_vector[0][2][15:4];
                    b_img[0][2] = ~unit_vector[0][2][31:20] ;

                    a_real[0][3] = H_backup[3][1][15:4];
                    a_img[0][3] =  H_backup[3][1][31:20];
                    b_real[0][3] = unit_vector[0][3][15:4];
                    b_img[0][3] = ~unit_vector[0][3][31:20] ;

                //Y43 Add 

                    add_in[1][0] = mult_out_real2[24:5];
                    add_in[1][1] = y_sum[2][19:0];

                    add_in2[0] = mult_out_img2[24:5];
                    add_in2[1] = y_sum[2][39:20];
                    
                    y_sum_nxt[2] = {adder_out[2][19:0],adder_out[1][19:0]};

                end 
            
            endcase
        end
    endcase

    //////////////////////////

    case(state)
        IDLE:begin                     
            if(i_trig)begin                   
                state_nxt = (iteration_cnt == 3 && cnt == 4)? RUN : state;
                for(i = 0; i < 4 ; i = i + 1)begin
                    for(j = 0; j < 4 ; j = j + 1)begin
                        H_nxt[i][j] = (iteration_cnt == i && cnt == j)? {i_data[47:32],i_data[23:8]} : H[i][j];
                        H_backup_nxt[i][j] = (iteration_cnt == i && cnt == j)? {i_data[47:32],i_data[23:8]} : H_backup_nxt[i][j]; //Laurent
                    end
                    Y_nxt[i] = (iteration_cnt == i && cnt == 4)? {i_data[47:32],i_data[23:8]} : Y[i];
                    Y_backup_nxt[i] = (iteration_cnt == i && cnt == 4)? {i_data[47:32],i_data[23:8]} : Y[i];
                end               
            end
            else begin
                cnt_nxt = cnt;
            end
        end

        RUN:begin

            //if(round_cnt != 10)  begin
                for(i = 0; i < 4 ; i = i + 1)begin
                    Y_nxt[i] = Y[i];
                end
                for(i = 0; i < 4 ; i = i + 1)begin
                    for(j = 0; j < 4 ; j = j + 1)begin            
                        H_backup_nxt[i][j] = (iteration_cnt == i && cnt == j)? {i_data[47:32],i_data[23:8]} : H_backup_nxt[i][j];
                        if (iteration_cnt == 3 && cnt == 4 && j!=3)begin
                            H_nxt[i][j] = H_backup[i][j];
                        end
                    end
                    Y_backup_nxt[i] = (iteration_cnt == i && cnt == 4)?{i_data[47:32],i_data[23:8]} : Y_backup[i];
                    if(iteration_cnt == 0 && cnt == 1) H_nxt[i][3] = H_backup[i][3];
                end 
                
                Y_nxt[0] = (iteration_cnt == 0 && cnt == 3)? Y_backup[0] : Y[0];
                Y_nxt[1] = (iteration_cnt == 0 && cnt == 3)? Y_backup[1] : Y[1];
                Y_nxt[2] = (iteration_cnt == 0 && cnt == 3)? Y_backup[2] : Y[2];
                Y_nxt[3] = (iteration_cnt == 0 && cnt == 3)? Y_backup[3] : Y[3]; 

                //////////////
                
                if(iteration_cnt == 2 && cnt == 4) begin
                    r_output_nxt = {r_output[319:260],Rij[4],Rij[2],Rii[2],Rij[3],Rij[1],Rii[1],Rij[0],Rii[0]}; //Laurent
                end
                if(iteration_cnt == 0 && cnt == 0) r_output_nxt = {sqrt_out,Rij[5],r_output[259:0]};//Laurent
                if(iteration_cnt == 0 && cnt == 0) begin //Laurent
                    y_output_nxt = {y_output[159:120],y_sum[2],y_sum[1],y_sum[0]}; 
                end
                
                if(iteration_cnt == 1 && cnt == 0) begin
                    y_output_nxt = {y_sum[3],y_output[119:0]};//Laurent
                end

            //H
            case(iteration_cnt) 
                0:begin
                    case(cnt)
                        1:begin
                        //H21 MUL
                            a_real[1][0] = Rij[0][19:8];
                            a_img[1][0] = {Rij[0][39:28]};
                            b_real[1][0] = unit_vector[0][0][15:4];
                            b_img[1][0] = unit_vector[0][0][31:20];

                            a_real[1][1] = Rij[0][19:8];
                            a_img[1][1] = {Rij[0][39:28]};
                            b_real[1][1] = unit_vector[0][1][15:4];
                            b_img[1][1] = unit_vector[0][1][31:20];

                            a_real[1][2] = Rij[0][19:8];
                            a_img[1][2] = {Rij[0][39:28]};
                            b_real[1][2] = unit_vector[0][2][15:4];
                            b_img[1][2] = unit_vector[0][2][31:20];

                            a_real[1][3] = Rij[0][19:8];
                            a_img[1][3] = {Rij[0][39:28]};
                            b_real[1][3] = unit_vector[0][3][15:4];
                            b_img[1][3] = unit_vector[0][3][31:20];

                        end
                        2:begin
                        //H21 Sub 

                            H_nxt[0][1][31:16] = H[0][1][31:16]+ ~mult_out_img[1][0][20:5];
                            H_nxt[1][1][31:16] = H[1][1][31:16]+ ~mult_out_img[1][1][20:5];
                            H_nxt[2][1][31:16] = H[2][1][31:16]+ ~mult_out_img[1][2][20:5];
                            H_nxt[3][1][31:16] = H[3][1][31:16]+ ~mult_out_img[1][3][20:5];

                            H_nxt[0][1][15:0] = H[0][1][15:0] + ~mult_out_real[1][0][20:5];
                            H_nxt[1][1][15:0] = H[1][1][15:0] + ~mult_out_real[1][1][20:5];
                            H_nxt[2][1][15:0] = H[2][1][15:0] + ~mult_out_real[1][2][20:5];
                            H_nxt[3][1][15:0] = H[3][1][15:0] + ~mult_out_real[1][3][20:5];

                        //H31 MUL
                            a_real[1][0] = Rij[1][19:8];
                            a_img[1][0] =  Rij[1][39:28];
                            b_real[1][0] = unit_vector[0][0][15:4];
                            b_img[1][0] = unit_vector[0][0][31:20] ;

                            a_real[1][1] = Rij[1][19:8];
                            a_img[1][1] =  Rij[1][39:28];
                            b_real[1][1] = unit_vector[0][1][15:4];
                            b_img[1][1] = unit_vector[0][1][31:20] ;

                            a_real[1][2] = Rij[1][19:8];
                            a_img[1][2] =  Rij[1][39:28];
                            b_real[1][2] = unit_vector[0][2][15:4];
                            b_img[1][2] = unit_vector[0][2][31:20] ;

                            a_real[1][3] = Rij[1][19:8];
                            a_img[1][3] =  Rij[1][39:28];
                            b_real[1][3] = unit_vector[0][3][15:4];
                            b_img[1][3] = unit_vector[0][3][31:20] ;

                        end
                        3:begin
                        //H31 Sub
                            H_nxt[0][2][31:16] = H[0][2][31:16]+ ~mult_out_img[1][0][20:5];
                            H_nxt[1][2][31:16] = H[1][2][31:16]+ ~mult_out_img[1][1][20:5];
                            H_nxt[2][2][31:16] = H[2][2][31:16]+ ~mult_out_img[1][2][20:5];
                            H_nxt[3][2][31:16] = H[3][2][31:16]+ ~mult_out_img[1][3][20:5];

                            H_nxt[0][2][15:0] = H[0][2][15:0] + ~mult_out_real[1][0][20:5];
                            H_nxt[1][2][15:0] = H[1][2][15:0] + ~mult_out_real[1][1][20:5];
                            H_nxt[2][2][15:0] = H[2][2][15:0] + ~mult_out_real[1][2][20:5];
                            H_nxt[3][2][15:0] = H[3][2][15:0] + ~mult_out_real[1][3][20:5];    
                            
                        end
                        4:begin
                        //H41 Mul
                            a_real[0][0] = {Rij[2][19:8]};
                            a_img[0][0] = {Rij[2][39:28]};
                            b_real[0][0] = unit_vector[0][0][15:4];
                            b_img[0][0] = unit_vector[0][0][31:20];                              
                            
                            a_real[0][1] = {Rij[2][19:8]};
                            a_img[0][1] = {Rij[2][39:28]};
                            b_real[0][1] = unit_vector[0][1][15:4];
                            b_img[0][1] = unit_vector[0][1][31:20];
                            
                            a_real[0][2] = {Rij[2][19:8]};
                            a_img[0][2] = {Rij[2][39:28]};
                            b_real[0][2] = unit_vector[0][2][15:4];
                            b_img[0][2] = unit_vector[0][2][31:20];
                            
                            a_real[0][3] = {Rij[2][19:8]};
                            a_img[0][3] = {Rij[2][39:28]};
                            b_real[0][3] = unit_vector[0][3][15:4];
                            b_img[0][3] = unit_vector[0][3][31:20];
                            
                        end   
                    endcase
                end
                1:begin
                    case(cnt)
                        0:begin
                        //H41 Sub
                            H_nxt[0][3][31:16] = H[0][3][31:16]+ ~mult_out_img[0][0][20:5];
                            H_nxt[1][3][31:16] = H[1][3][31:16]+ ~ mult_out_img[0][1][20:5];
                            H_nxt[2][3][31:16] = H[2][3][31:16]+ ~ mult_out_img[0][2][20:5];
                            H_nxt[3][3][31:16] = H[3][3][31:16]+ ~ mult_out_img[0][3][20:5];

                            H_nxt[0][3][15:0] = H[0][3][15:0] + ~ mult_out_real[0][0][20:5];
                            H_nxt[1][3][15:0] = H[1][3][15:0] + ~ mult_out_real[0][1][20:5];
                            H_nxt[2][3][15:0] = H[2][3][15:0] + ~ mult_out_real[0][2][20:5];
                            H_nxt[3][3][15:0] = H[3][3][15:0] + ~ mult_out_real[0][3][20:5];
                        end
                        4:begin
                        //H32 Mul
                            a_real[0][0] = {Rij[3][19:8]};
                            a_img[0][0] = {Rij[3][39:28]};
                            b_real[0][0] = unit_vector[1][0][15:4];
                            b_img[0][0] = unit_vector[1][0][31:20];                              
                            
                            a_real[0][1] = {Rij[3][19:8]};
                            a_img[0][1] = {Rij[3][39:28]};
                            b_real[0][1] = unit_vector[1][1][15:4];
                            b_img[0][1] = unit_vector[1][1][31:20];
                            
                            a_real[0][2] = {Rij[3][19:8]};
                            a_img[0][2] = {Rij[3][39:28]};
                            b_real[0][2] = unit_vector[1][2][15:4];
                            b_img[0][2] = unit_vector[1][2][31:20];
                            
                            a_real[0][3] = {Rij[3][19:8]};
                            a_img[0][3] = {Rij[3][39:28]};
                            b_real[0][3] = unit_vector[1][3][15:4];
                            b_img[0][3] = unit_vector[1][3][31:20];  
                        end
                    endcase
                end
                2:begin
                    case(cnt)
                        0:begin
                        //H32 Sub
                            H_nxt[0][2][31:16] = H[0][2][31:16]+ ~mult_out_img[0][0][20:5];
                            H_nxt[1][2][31:16] = H[1][2][31:16]+ ~mult_out_img[0][1][20:5];
                            H_nxt[2][2][31:16] = H[2][2][31:16]+ ~mult_out_img[0][2][20:5];
                            H_nxt[3][2][31:16] = H[3][2][31:16]+ ~mult_out_img[0][3][20:5];

                            H_nxt[0][2][15:0] = H[0][2][15:0] + ~mult_out_real[0][0][20:5];
                            H_nxt[1][2][15:0] = H[1][2][15:0] + ~mult_out_real[0][1][20:5];
                            H_nxt[2][2][15:0] = H[2][2][15:0] + ~mult_out_real[0][2][20:5];
                            H_nxt[3][2][15:0] = H[3][2][15:0] + ~mult_out_real[0][3][20:5];
                            
                        //H42 Mul
                            a_real[0][0] = {Rij[4][19:8]};
                            a_img[0][0] = {Rij[4][39:28]};
                            b_real[0][0] = unit_vector[1][0][15:4];
                            b_img[0][0] = unit_vector[1][0][31:20];                              
                            
                            a_real[0][1] = {Rij[4][19:8]};
                            a_img[0][1] = {Rij[4][39:28]};
                            b_real[0][1] = unit_vector[1][1][15:4];
                            b_img[0][1] = unit_vector[1][1][31:20];
                            
                            a_real[0][2] = {Rij[4][19:8]};
                            a_img[0][2] = {Rij[4][39:28]};
                            b_real[0][2] = unit_vector[1][2][15:4];
                            b_img[0][2] = unit_vector[1][2][31:20];
                            
                            a_real[0][3] = {Rij[4][19:8]};
                            a_img[0][3] = {Rij[4][39:28]};
                            b_real[0][3] = unit_vector[1][3][15:4];
                            b_img[0][3] = unit_vector[1][3][31:20];
                        end
                        1:begin
                        //H42 Sub
                            H_nxt[0][3][31:16] = H[0][3][31:16]+ ~mult_out_img[0][0][20:5];
                            H_nxt[1][3][31:16] = H[1][3][31:16]+ ~mult_out_img[0][1][20:5];
                            H_nxt[2][3][31:16] = H[2][3][31:16]+ ~mult_out_img[0][2][20:5];
                            H_nxt[3][3][31:16] = H[3][3][31:16]+ ~mult_out_img[0][3][20:5];

                            H_nxt[0][3][15:0] = H[0][3][15:0] + ~mult_out_real[0][0][20:5];
                            H_nxt[1][3][15:0] = H[1][3][15:0] + ~mult_out_real[0][1][20:5];
                            H_nxt[2][3][15:0] = H[2][3][15:0] + ~mult_out_real[0][2][20:5];
                            H_nxt[3][3][15:0] = H[3][3][15:0] + ~mult_out_real[0][3][20:5];
                        end
                    endcase
                end
                3:begin
                    case(cnt)
                        2:begin
                        //H43 Mul
                            a_real[1][0] = {Rij[5][19:8]};
                            a_img[1][0] = {Rij[5][39:28]};
                            b_real[1][0] = unit_vector[2][0][15:4];
                            b_img[1][0] = unit_vector[2][0][31:20];                              
                            
                            a_real[1][1] = {Rij[5][19:8]};
                            a_img[1][1] = {Rij[5][39:28]};
                            b_real[1][1] = unit_vector[2][1][15:4];
                            b_img[1][1] = unit_vector[2][1][31:20];
                            
                            a_real[1][2] = {Rij[5][19:8]};
                            a_img[1][2] = {Rij[5][39:28]};
                            b_real[1][2] = unit_vector[2][2][15:4];
                            b_img[1][2] = unit_vector[2][2][31:20];
                            
                            a_real[1][3] = {Rij[5][19:8]};
                            a_img[1][3] = {Rij[5][39:28]};
                            b_real[1][3] = unit_vector[2][3][15:4];
                            b_img[1][3] = unit_vector[2][3][31:20];

                        end
                        3:begin
                        //H43 Sub
                            H_nxt[0][3][31:16] = H[0][3][31:16]+ ~mult_out_img[1][0][20:5];
                            H_nxt[1][3][31:16] = H[1][3][31:16]+ ~mult_out_img[1][1][20:5];
                            H_nxt[2][3][31:16] = H[2][3][31:16]+ ~mult_out_img[1][2][20:5];
                            H_nxt[3][3][31:16] = H[3][3][31:16]+ ~mult_out_img[1][3][20:5];

                            H_nxt[0][3][15:0] = H[0][3][15:0] + ~mult_out_real[1][0][20:5];
                            H_nxt[1][3][15:0] = H[1][3][15:0] + ~mult_out_real[1][1][20:5];
                            H_nxt[2][3][15:0] = H[2][3][15:0] + ~mult_out_real[1][2][20:5];
                            H_nxt[3][3][15:0] = H[3][3][15:0] + ~mult_out_real[1][3][20:5];
                        end
                    endcase
                end
            endcase                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
            
        end

    endcase
    
end

always @(posedge i_clk or posedge i_rst)begin
    if(i_rst)begin
        for(i = 0; i < 4 ; i = i + 1)begin
            for(j = 0; j < 4 ; j = j + 1)begin
                H[i][j] <= 0;
                H_backup[i][j] <= 0;
                Y[i] <= 0;
                
            end
        end
        for(i = 0; i < 4 ; i = i + 1)begin
            Rii[i] <= 0;
            Y[i] <= 0;
            Y_backup[i] <= 0;
            y_sum[i] <= 0;
        end
        for(i = 0; i < 6 ; i = i + 1)begin
            Rij[i] <= 0;
        end
        for(i = 0; i < 4 ; i = i + 1)begin
            for(j = 0; j < 4 ; j = j + 1)begin
                unit_vector[i][j] <= 0;
            end
        end
        round_cnt <= 0;
        iteration_cnt <= 0;
        cnt <= 0;
        state <= 0;
        distance <= 0;
        r_output <= 0;
        y_output <= 0;
        out_yes <= 0;
        
    end
    else begin
        for(i = 0; i < 4 ; i = i + 1)begin
            for(j = 0; j < 4 ; j = j + 1)begin
                H[i][j] <= H_nxt[i][j];
                H_backup[i][j] <= H_backup_nxt[i][j];
                unit_vector[i][j] <= unit_vector_nxt[i][j];
            end
        end
        for(i = 0; i < 4 ; i = i + 1)begin
            Rii[i] <= Rii_nxt[i];
            Y[i] <= Y_nxt[i];
            Y_backup[i] <= Y_backup_nxt[i];
            y_sum[i] <= y_sum_nxt[i];
        end
        for(i = 0; i < 6 ; i = i + 1)begin
            Rij[i] <= Rij_nxt[i];
        end
        for(i = 0; i < 4 ; i = i + 1)begin
            for(j = 0; j < 4 ; j = j + 1)begin
                unit_vector[i][j] <= unit_vector_nxt[i][j];
            end
        end
        cnt <= cnt_nxt;
        state <= state_nxt;
        distance <= distance_nxt;
        iteration_cnt <= iteration_cnt_nxt;
        r_output <= r_output_nxt;
        y_output <= y_output_nxt;
        round_cnt <= round_cnt_nxt;
        out_yes <= out_yes_nxt;
    end
end

//MODULE

cordic_sqrt sqrt(
    .i_sqrt_in(sqrt_in), //6.32
    .sqrt_out(sqrt_out)
);

complex_mult m00(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[0][0]),
    .i_q_img(a_img[0][0]),
    .i_y_real(b_real[0][0]),
    .i_y_img(b_img[0][0]),
    .o_mult_real(mult_out_real[0][0]),
    .o_mult_img(mult_out_img[0][0])
 );

complex_mult m01(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[0][1]),
    .i_q_img(a_img[0][1]),
    .i_y_real(b_real[0][1]),
    .i_y_img(b_img[0][1]),
    .o_mult_real(mult_out_real[0][1]),
    .o_mult_img(mult_out_img[0][1])
 );

complex_mult m02(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[0][2]),
    .i_q_img(a_img[0][2]),
    .i_y_real(b_real[0][2]),
    .i_y_img(b_img[0][2]),
    .o_mult_real(mult_out_real[0][2]),
    .o_mult_img(mult_out_img[0][2])
 );

complex_mult m03(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[0][3]),
    .i_q_img(a_img[0][3]),
    .i_y_real(b_real[0][3]),
    .i_y_img(b_img[0][3]),
    .o_mult_real(mult_out_real[0][3]),
    .o_mult_img(mult_out_img[0][3])
 );

complex_mult m10(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[1][0]),
    .i_q_img(a_img[1][0]),
    .i_y_real(b_real[1][0]),
    .i_y_img(b_img[1][0]),
    .o_mult_real(mult_out_real[1][0]),
    .o_mult_img(mult_out_img[1][0])
 );

complex_mult m11(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[1][1]),
    .i_q_img(a_img[1][1]),
    .i_y_real(b_real[1][1]),
    .i_y_img(b_img[1][1]),
    .o_mult_real(mult_out_real[1][1]),
    .o_mult_img(mult_out_img[1][1])
 );

complex_mult m12(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[1][2]),
    .i_q_img(a_img[1][2]),
    .i_y_real(b_real[1][2]),
    .i_y_img(b_img[1][2]),
    .o_mult_real(mult_out_real[1][2]),
    .o_mult_img(mult_out_img[1][2])
 );

complex_mult m13(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real[1][3]),
    .i_q_img(a_img[1][3]),
    .i_y_real(b_real[1][3]),
    .i_y_img(b_img[1][3]),
    .o_mult_real(mult_out_real[1][3]),
    .o_mult_img(mult_out_img[1][3])
 );

complex_mult m20(
    .i_clk(i_clk),
    .i_rst(i_rst),
    .i_q_real(a_real2),
    .i_q_img(a_img2),
    .i_y_real(b_real2),
    .i_y_img(b_img2),
    .o_mult_real(mult_out_real2),
    .o_mult_img(mult_out_img2)
 );

square_add square_adder0(
    .i_adder_1(add_in[0][0]),
    .i_adder_2(add_in[0][1]),
    .i_adder_3(add_in[0][2]),
    .i_adder_4(add_in[0][3]),
    .o_mid_sum1(mid_sum1[0]),
    .o_mid_sum2(mid_sum2[0]),
    .o_adder(adder_out[0]) 
);
square_add square_adder1(
    .i_adder_1(add_in[1][0]),
    .i_adder_2(add_in[1][1]),
    .i_adder_3(add_in[1][2]),
    .i_adder_4(add_in[1][3]),
    .o_mid_sum1(mid_sum1[1]),
    .o_mid_sum2(mid_sum2[1]),
    .o_adder(adder_out[1]) 
);
square_add square_adder2(
    .i_adder_1(add_in2[0]),
    .i_adder_2(add_in2[1]),
    .i_adder_3(add_in2[2]),
    .i_adder_4(add_in2[3]),
    .o_mid_sum1(mid_sum1[2]),
    .o_mid_sum2(mid_sum2[2]),
    .o_adder(adder_out[2]) 
);


Inv_sqrt Inv_sqrt(
	.i_sqrt_in(sqrt_in),
	.sqrt_out(inv_sqrt_out) 
);

endmodule

////////////////////
module square_add(
    input signed[19:0] i_adder_1,
    input signed[19:0] i_adder_2,
    input signed[19:0] i_adder_3,
    input signed[19:0] i_adder_4,
    output reg signed [20:0] o_mid_sum1,
    output reg signed [20:0] o_mid_sum2,
    output reg signed [21:0] o_adder 
    );
    always @(*) begin
        o_mid_sum1 =  i_adder_1 + i_adder_2;
        o_mid_sum2 =  i_adder_3 + i_adder_4;
        o_adder =  o_mid_sum1 + o_mid_sum2;
    end
endmodule
////////////////////

module complex_mult(
    input i_clk,
    input i_rst,
    input [11:0] i_q_real,
    input [11:0] i_q_img,
    input [11:0] i_y_real,
    input [11:0] i_y_img,
    output reg signed  [24:0] o_mult_real,
    output reg signed  [24:0] o_mult_img 
    );
    reg [24:0] temp_1_real,temp_1_img,temp_2_real,temp_2_img;
    reg signed [23:0] mult[0:3];
    
    always @(*)begin
        o_mult_real = temp_1_real + temp_2_real;
        o_mult_img = temp_1_img + temp_2_img;

        mult[0] = $signed(i_q_real) * $signed(i_y_real);
        mult[1] = $signed(i_q_real) * $signed(i_y_img);
        mult[2] = ~($signed(i_q_img) * $signed(i_y_img));
        mult[3] = $signed(i_q_img) * $signed(i_y_real);
    end

    always @(posedge i_clk or posedge i_rst)begin
        if(i_rst)begin
            temp_1_real <= 0;
            temp_1_img <=  0;
            temp_2_real <= 0;
            temp_2_img <=  0;
        end
        else begin
            temp_1_real <= {mult[0][23],mult[0]};
            temp_1_img <= {mult[1][23],mult[1]};
            temp_2_real <= {mult[2][23],mult[2]};
            temp_2_img <= {mult[3][23],mult[3]};
        end
    end

endmodule


module cordic_sqrt( 
    input  [13:0]i_sqrt_in, // 4.10
    output reg [18:0] sqrt_out  //3.16
    );

    // reg [18:0] sqrt_out; 
    integer i;

    // assign o_sqrt_a = sqrt_out;

    always@(*)begin 
        if(i_sqrt_in[13])begin
            case(i_sqrt_in[12:8])
                0 : sqrt_out = 19'd185363;
                1 : sqrt_out = 19'd188237;
                2 : sqrt_out = 19'd191068;
                3 : sqrt_out = 19'd193858;
                4 : sqrt_out = 19'd196608;
                5 : sqrt_out = 19'd199319;
                6 : sqrt_out = 19'd201995;
                7 : sqrt_out = 19'd204636;
                8 : sqrt_out = 19'd207243;
                9 : sqrt_out = 19'd209817;
                10 : sqrt_out = 19'd212360;
                11 : sqrt_out = 19'd214874;
                12 : sqrt_out = 19'd217358;
                13 : sqrt_out = 19'd219814;
                14 : sqrt_out = 19'd222243;
                15 : sqrt_out = 19'd224646;
                16 : sqrt_out = 19'd227023;
                17 : sqrt_out = 19'd229376;
                18 : sqrt_out = 19'd231704;
                19 : sqrt_out = 19'd234010;
                20 : sqrt_out = 19'd236293;
                21 : sqrt_out = 19'd238554;
                22 : sqrt_out = 19'd240794;
                23 : sqrt_out = 19'd243013;
                24 : sqrt_out = 19'd245213;
                25 : sqrt_out = 19'd247392;
                26 : sqrt_out = 19'd249553;
                27 : sqrt_out = 19'd251695;
                28 : sqrt_out = 19'd253819;
                29 : sqrt_out = 19'd255926;
                30 : sqrt_out = 19'd258015;
                31 : sqrt_out = 19'd260087;

            endcase
        end
        else if(i_sqrt_in[12])begin
            case(i_sqrt_in[11:7])
                0 : sqrt_out = 19'd131072;
                1 : sqrt_out = 19'd133104;
                2 : sqrt_out = 19'd135105;
                3 : sqrt_out = 19'd137078;
                4 : sqrt_out = 19'd139022;
                5 : sqrt_out = 19'd140940;
                6 : sqrt_out = 19'd142832;
                7 : sqrt_out = 19'd144699;
                8 : sqrt_out = 19'd146542;
                9 : sqrt_out = 19'd148363;
                10 : sqrt_out = 19'd150161;
                11 : sqrt_out = 19'd151938;
                12 : sqrt_out = 19'd153695;
                13 : sqrt_out = 19'd155432;
                14 : sqrt_out = 19'd157149;
                15 : sqrt_out = 19'd158848;
                16 : sqrt_out = 19'd160529;
                17 : sqrt_out = 19'd162193;
                18 : sqrt_out = 19'd163840;
                19 : sqrt_out = 19'd165470;
                20 : sqrt_out = 19'd167084;
                21 : sqrt_out = 19'd168683;
                22 : sqrt_out = 19'd170267;
                23 : sqrt_out = 19'd171836;
                24 : sqrt_out = 19'd173391;
                25 : sqrt_out = 19'd174933;
                26 : sqrt_out = 19'd176461;
                27 : sqrt_out = 19'd177975;
                28 : sqrt_out = 19'd179477;
                29 : sqrt_out = 19'd180967;
                30 : sqrt_out = 19'd182444;
                31 : sqrt_out = 19'd183909;

            endcase
        end
        else if(i_sqrt_in[11])begin
            case(i_sqrt_in[10:6])
                0 : sqrt_out = 19'd92681;
                1 : sqrt_out = 19'd94118;
                2 : sqrt_out = 19'd95534;
                3 : sqrt_out = 19'd96929;
                4 : sqrt_out = 19'd98304;
                5 : sqrt_out = 19'd99659;
                6 : sqrt_out = 19'd100997;
                7 : sqrt_out = 19'd102318;
                8 : sqrt_out = 19'd103621;
                9 : sqrt_out = 19'd104908;
                10 : sqrt_out = 19'd106180;
                11 : sqrt_out = 19'd107437;
                12 : sqrt_out = 19'd108679;
                13 : sqrt_out = 19'd109907;
                14 : sqrt_out = 19'd111121;
                15 : sqrt_out = 19'd112323;
                16 : sqrt_out = 19'd113511;
                17 : sqrt_out = 19'd114688;
                18 : sqrt_out = 19'd115852;
                19 : sqrt_out = 19'd117005;
                20 : sqrt_out = 19'd118146;
                21 : sqrt_out = 19'd119277;
                22 : sqrt_out = 19'd120397;
                23 : sqrt_out = 19'd121506;
                24 : sqrt_out = 19'd122606;
                25 : sqrt_out = 19'd123696;
                26 : sqrt_out = 19'd124776;
                27 : sqrt_out = 19'd125847;
                28 : sqrt_out = 19'd126909;
                29 : sqrt_out = 19'd127963;
                30 : sqrt_out = 19'd129007;
                31 : sqrt_out = 19'd130043;

            endcase
        end
        else if(i_sqrt_in[10])begin
            case(i_sqrt_in[9:5])
                0 : sqrt_out = 19'd65536;
                1 : sqrt_out = 19'd66552;
                2 : sqrt_out = 19'd67552;
                3 : sqrt_out = 19'd68539;
                4 : sqrt_out = 19'd69511;
                5 : sqrt_out = 19'd70470;
                6 : sqrt_out = 19'd71416;
                7 : sqrt_out = 19'd72349;
                8 : sqrt_out = 19'd73271;
                9 : sqrt_out = 19'd74181;
                10 : sqrt_out = 19'd75080;
                11 : sqrt_out = 19'd75969;
                12 : sqrt_out = 19'd76847;
                13 : sqrt_out = 19'd77716;
                14 : sqrt_out = 19'd78574;
                15 : sqrt_out = 19'd79424;
                16 : sqrt_out = 19'd80264;
                17 : sqrt_out = 19'd81096;
                18 : sqrt_out = 19'd81920;
                19 : sqrt_out = 19'd82735;
                20 : sqrt_out = 19'd83542;
                21 : sqrt_out = 19'd84341;
                22 : sqrt_out = 19'd85133;
                23 : sqrt_out = 19'd85918;
                24 : sqrt_out = 19'd86695;
                25 : sqrt_out = 19'd87466;
                26 : sqrt_out = 19'd88230;
                27 : sqrt_out = 19'd88987;
                28 : sqrt_out = 19'd89738;
                29 : sqrt_out = 19'd90483;
                30 : sqrt_out = 19'd91222;
                31 : sqrt_out = 19'd91954;

            endcase
        end
        else if(i_sqrt_in[9])begin
            case(i_sqrt_in[8:4])
                0 : sqrt_out = 19'd46340;
                1 : sqrt_out = 19'd47059;
                2 : sqrt_out = 19'd47767;
                3 : sqrt_out = 19'd48464;
                4 : sqrt_out = 19'd49152;
                5 : sqrt_out = 19'd49829;
                6 : sqrt_out = 19'd50498;
                7 : sqrt_out = 19'd51159;
                8 : sqrt_out = 19'd51810;
                9 : sqrt_out = 19'd52454;
                10 : sqrt_out = 19'd53090;
                11 : sqrt_out = 19'd53718;
                12 : sqrt_out = 19'd54339;
                13 : sqrt_out = 19'd54953;
                14 : sqrt_out = 19'd55560;
                15 : sqrt_out = 19'd56161;
                16 : sqrt_out = 19'd56755;
                17 : sqrt_out = 19'd57344;
                18 : sqrt_out = 19'd57926;
                19 : sqrt_out = 19'd58502;
                20 : sqrt_out = 19'd59073;
                21 : sqrt_out = 19'd59638;
                22 : sqrt_out = 19'd60198;
                23 : sqrt_out = 19'd60753;
                24 : sqrt_out = 19'd61303;
                25 : sqrt_out = 19'd61848;
                26 : sqrt_out = 19'd62388;
                27 : sqrt_out = 19'd62923;
                28 : sqrt_out = 19'd63454;
                29 : sqrt_out = 19'd63981;
                30 : sqrt_out = 19'd64503;
                31 : sqrt_out = 19'd65021;

            endcase
        end
        else if(i_sqrt_in[8])begin
            case(i_sqrt_in[7:3])
                0 : sqrt_out = 19'd32768;
                1 : sqrt_out = 19'd33276;
                2 : sqrt_out = 19'd33776;
                3 : sqrt_out = 19'd34269;
                4 : sqrt_out = 19'd34755;
                5 : sqrt_out = 19'd35235;
                6 : sqrt_out = 19'd35708;
                7 : sqrt_out = 19'd36174;
                8 : sqrt_out = 19'd36635;
                9 : sqrt_out = 19'd37090;
                10 : sqrt_out = 19'd37540;
                11 : sqrt_out = 19'd37984;
                12 : sqrt_out = 19'd38423;
                13 : sqrt_out = 19'd38858;
                14 : sqrt_out = 19'd39287;
                15 : sqrt_out = 19'd39712;
                16 : sqrt_out = 19'd40132;
                17 : sqrt_out = 19'd40548;
                18 : sqrt_out = 19'd40960;
                19 : sqrt_out = 19'd41367;
                20 : sqrt_out = 19'd41771;
                21 : sqrt_out = 19'd42170;
                22 : sqrt_out = 19'd42566;
                23 : sqrt_out = 19'd42959;
                24 : sqrt_out = 19'd43347;
                25 : sqrt_out = 19'd43733;
                26 : sqrt_out = 19'd44115;
                27 : sqrt_out = 19'd44493;
                28 : sqrt_out = 19'd44869;
                29 : sqrt_out = 19'd45241;
                30 : sqrt_out = 19'd45611;
                31 : sqrt_out = 19'd45977;

            endcase
        end
        else if(i_sqrt_in[7])begin
            case(i_sqrt_in[6:2])
                0 : sqrt_out = 19'd23170;
                1 : sqrt_out = 19'd23529;
                2 : sqrt_out = 19'd23883;
                3 : sqrt_out = 19'd24232;
                4 : sqrt_out = 19'd24576;
                5 : sqrt_out = 19'd24914;
                6 : sqrt_out = 19'd25249;
                7 : sqrt_out = 19'd25579;
                8 : sqrt_out = 19'd25905;
                9 : sqrt_out = 19'd26227;
                10 : sqrt_out = 19'd26545;
                11 : sqrt_out = 19'd26859;
                12 : sqrt_out = 19'd27169;
                13 : sqrt_out = 19'd27476;
                14 : sqrt_out = 19'd27780;
                15 : sqrt_out = 19'd28080;
                16 : sqrt_out = 19'd28377;
                17 : sqrt_out = 19'd28672;
                18 : sqrt_out = 19'd28963;
                19 : sqrt_out = 19'd29251;
                20 : sqrt_out = 19'd29536;
                21 : sqrt_out = 19'd29819;
                22 : sqrt_out = 19'd30099;
                23 : sqrt_out = 19'd30376;
                24 : sqrt_out = 19'd30651;
                25 : sqrt_out = 19'd30924;
                26 : sqrt_out = 19'd31194;
                27 : sqrt_out = 19'd31461;
                28 : sqrt_out = 19'd31727;
                29 : sqrt_out = 19'd31990;
                30 : sqrt_out = 19'd32251;
                31 : sqrt_out = 19'd32510;

            endcase
        end
        else if(i_sqrt_in[6])begin
            case(i_sqrt_in[5:1])
                0 : sqrt_out = 19'd16384;
                1 : sqrt_out = 19'd16638;
                2 : sqrt_out = 19'd16888;
                3 : sqrt_out = 19'd17134;
                4 : sqrt_out = 19'd17377;
                5 : sqrt_out = 19'd17617;
                6 : sqrt_out = 19'd17854;
                7 : sqrt_out = 19'd18087;
                8 : sqrt_out = 19'd18317;
                9 : sqrt_out = 19'd18545;
                10 : sqrt_out = 19'd18770;
                11 : sqrt_out = 19'd18992;
                12 : sqrt_out = 19'd19211;
                13 : sqrt_out = 19'd19429;
                14 : sqrt_out = 19'd19643;
                15 : sqrt_out = 19'd19856;
                16 : sqrt_out = 19'd20066;
                17 : sqrt_out = 19'd20274;
                18 : sqrt_out = 19'd20480;
                19 : sqrt_out = 19'd20683;
                20 : sqrt_out = 19'd20885;
                21 : sqrt_out = 19'd21085;
                22 : sqrt_out = 19'd21283;
                23 : sqrt_out = 19'd21479;
                24 : sqrt_out = 19'd21673;
                25 : sqrt_out = 19'd21866;
                26 : sqrt_out = 19'd22057;
                27 : sqrt_out = 19'd22246;
                28 : sqrt_out = 19'd22434;
                29 : sqrt_out = 19'd22620;
                30 : sqrt_out = 19'd22805;
                31 : sqrt_out = 19'd22988;

            endcase
        end
        else if(i_sqrt_in[5])begin
            case(i_sqrt_in[4:0])
                0 : sqrt_out = 19'd11585;
                1 : sqrt_out = 19'd11764;
                2 : sqrt_out = 19'd11941;
                3 : sqrt_out = 19'd12116;
                4 : sqrt_out = 19'd12288;
                5 : sqrt_out = 19'd12457;
                6 : sqrt_out = 19'd12624;
                7 : sqrt_out = 19'd12789;
                8 : sqrt_out = 19'd12952;
                9 : sqrt_out = 19'd13113;
                10 : sqrt_out = 19'd13272;
                11 : sqrt_out = 19'd13429;
                12 : sqrt_out = 19'd13584;
                13 : sqrt_out = 19'd13738;
                14 : sqrt_out = 19'd13890;
                15 : sqrt_out = 19'd14040;
                16 : sqrt_out = 19'd14188;
                17 : sqrt_out = 19'd14336;
                18 : sqrt_out = 19'd14481;
                19 : sqrt_out = 19'd14625;
                20 : sqrt_out = 19'd14768;
                21 : sqrt_out = 19'd14909;
                22 : sqrt_out = 19'd15049;
                23 : sqrt_out = 19'd15188;
                24 : sqrt_out = 19'd15325;
                25 : sqrt_out = 19'd15462;
                26 : sqrt_out = 19'd15597;
                27 : sqrt_out = 19'd15730;
                28 : sqrt_out = 19'd15863;
                29 : sqrt_out = 19'd15995;
                30 : sqrt_out = 19'd16125;
                31 : sqrt_out = 19'd16255;

            endcase
        end
        else sqrt_out = 19'd11585;
    end
endmodule

/*
module Inv_sqrt( 
    input [13:0] i_sqrt_in,
    output [10:0] o_inv_sqrt_out 
    );

    reg [10 : 0 ] sqrt_out;

    assign o_inv_sqrt_out = sqrt_out; 

    always@(*)begin 
        if(i_sqrt_in[13])begin
            case(i_sqrt_in[12:8])
                0 : sqrt_out = 11'd89;
                1 : sqrt_out = 11'd88;
                2 : sqrt_out = 11'd87;
                3 : sqrt_out = 11'd85;
                4 : sqrt_out = 11'd84;
                5 : sqrt_out = 11'd83;
                6 : sqrt_out = 11'd82;
                7 : sqrt_out = 11'd81;
                8 : sqrt_out = 11'd80;
                9 : sqrt_out = 11'd79;
                10 : sqrt_out = 11'd78;
                11 : sqrt_out = 11'd77;
                12 : sqrt_out = 11'd76;
                13 : sqrt_out = 11'd75;
                14 : sqrt_out = 11'd75;
                15 : sqrt_out = 11'd74;
                16 : sqrt_out = 11'd73;
                17 : sqrt_out = 11'd72;
                18 : sqrt_out = 11'd72;
                19 : sqrt_out = 11'd71;
                20 : sqrt_out = 11'd70;
                21 : sqrt_out = 11'd69;
                22 : sqrt_out = 11'd69;
                23 : sqrt_out = 11'd68;
                24 : sqrt_out = 11'd68;
                25 : sqrt_out = 11'd67;
                26 : sqrt_out = 11'd66;
                27 : sqrt_out = 11'd66;
                28 : sqrt_out = 11'd65;
                29 : sqrt_out = 11'd65;
                30 : sqrt_out = 11'd64;
                31 : sqrt_out = 11'd64;

            endcase
        end
        else if(i_sqrt_in[12])begin
            case(i_sqrt_in[11:7])
                0 : sqrt_out = 11'd127;
                1 : sqrt_out = 11'd125;
                2 : sqrt_out = 11'd123;
                3 : sqrt_out = 11'd121;
                4 : sqrt_out = 11'd119;
                5 : sqrt_out = 11'd118;
                6 : sqrt_out = 11'd116;
                7 : sqrt_out = 11'd115;
                8 : sqrt_out = 11'd113;
                9 : sqrt_out = 11'd112;
                10 : sqrt_out = 11'd111;
                11 : sqrt_out = 11'd109;
                12 : sqrt_out = 11'd108;
                13 : sqrt_out = 11'd107;
                14 : sqrt_out = 11'd106;
                15 : sqrt_out = 11'd105;
                16 : sqrt_out = 11'd103;
                17 : sqrt_out = 11'd102;
                18 : sqrt_out = 11'd101;
                19 : sqrt_out = 11'd100;
                20 : sqrt_out = 11'd99;
                21 : sqrt_out = 11'd98;
                22 : sqrt_out = 11'd98;
                23 : sqrt_out = 11'd97;
                24 : sqrt_out = 11'd96;
                25 : sqrt_out = 11'd95;
                26 : sqrt_out = 11'd94;
                27 : sqrt_out = 11'd93;
                28 : sqrt_out = 11'd93;
                29 : sqrt_out = 11'd92;
                30 : sqrt_out = 11'd91;
                31 : sqrt_out = 11'd90;

            endcase
        end
        else if(i_sqrt_in[11])begin
            case(i_sqrt_in[10:6])
                0 : sqrt_out = 11'd179;
                1 : sqrt_out = 11'd176;
                2 : sqrt_out = 11'd174;
                3 : sqrt_out = 11'd171;
                4 : sqrt_out = 11'd169;
                5 : sqrt_out = 11'd167;
                6 : sqrt_out = 11'd165;
                7 : sqrt_out = 11'd162;
                8 : sqrt_out = 11'd160;
                9 : sqrt_out = 11'd158;
                10 : sqrt_out = 11'd157;
                11 : sqrt_out = 11'd155;
                12 : sqrt_out = 11'd153;
                13 : sqrt_out = 11'd151;
                14 : sqrt_out = 11'd150;
                15 : sqrt_out = 11'd148;
                16 : sqrt_out = 11'd147;
                17 : sqrt_out = 11'd145;
                18 : sqrt_out = 11'd144;
                19 : sqrt_out = 11'd142;
                20 : sqrt_out = 11'd141;
                21 : sqrt_out = 11'd139;
                22 : sqrt_out = 11'd138;
                23 : sqrt_out = 11'd137;
                24 : sqrt_out = 11'd136;
                25 : sqrt_out = 11'd135;
                26 : sqrt_out = 11'd133;
                27 : sqrt_out = 11'd132;
                28 : sqrt_out = 11'd131;
                29 : sqrt_out = 11'd130;
                30 : sqrt_out = 11'd129;
                31 : sqrt_out = 11'd128;

            endcase
        end
        else if(i_sqrt_in[10])begin
            case(i_sqrt_in[9:5])
                0 : sqrt_out = 11'd254;
                1 : sqrt_out = 11'd250;
                2 : sqrt_out = 11'd246;
                3 : sqrt_out = 11'd243;
                4 : sqrt_out = 11'd239;
                5 : sqrt_out = 11'd236;
                6 : sqrt_out = 11'd233;
                7 : sqrt_out = 11'd230;
                8 : sqrt_out = 11'd227;
                9 : sqrt_out = 11'd224;
                10 : sqrt_out = 11'd222;
                11 : sqrt_out = 11'd219;
                12 : sqrt_out = 11'd217;
                13 : sqrt_out = 11'd214;
                14 : sqrt_out = 11'd212;
                15 : sqrt_out = 11'd210;
                16 : sqrt_out = 11'd207;
                17 : sqrt_out = 11'd205;
                18 : sqrt_out = 11'd203;
                19 : sqrt_out = 11'd201;
                20 : sqrt_out = 11'd199;
                21 : sqrt_out = 11'd197;
                22 : sqrt_out = 11'd196;
                23 : sqrt_out = 11'd194;
                24 : sqrt_out = 11'd192;
                25 : sqrt_out = 11'd190;
                26 : sqrt_out = 11'd189;
                27 : sqrt_out = 11'd187;
                28 : sqrt_out = 11'd186;
                29 : sqrt_out = 11'd184;
                30 : sqrt_out = 11'd183;
                31 : sqrt_out = 11'd181;

            endcase
        end
        else if(i_sqrt_in[9])begin
            case(i_sqrt_in[8:4])
                0 : sqrt_out = 11'd359;
                1 : sqrt_out = 11'd353;
                2 : sqrt_out = 11'd348;
                3 : sqrt_out = 11'd343;
                4 : sqrt_out = 11'd338;
                5 : sqrt_out = 11'd334;
                6 : sqrt_out = 11'd330;
                7 : sqrt_out = 11'd325;
                8 : sqrt_out = 11'd321;
                9 : sqrt_out = 11'd317;
                10 : sqrt_out = 11'd314;
                11 : sqrt_out = 11'd310;
                12 : sqrt_out = 11'd307;
                13 : sqrt_out = 11'd303;
                14 : sqrt_out = 11'd300;
                15 : sqrt_out = 11'd297;
                16 : sqrt_out = 11'd294;
                17 : sqrt_out = 11'd291;
                18 : sqrt_out = 11'd288;
                19 : sqrt_out = 11'd285;
                20 : sqrt_out = 11'd282;
                21 : sqrt_out = 11'd279;
                22 : sqrt_out = 11'd277;
                23 : sqrt_out = 11'd274;
                24 : sqrt_out = 11'd272;
                25 : sqrt_out = 11'd270;
                26 : sqrt_out = 11'd267;
                27 : sqrt_out = 11'd265;
                28 : sqrt_out = 11'd263;
                29 : sqrt_out = 11'd261;
                30 : sqrt_out = 11'd259;
                31 : sqrt_out = 11'd257;

            endcase
        end
        else if(i_sqrt_in[8])begin
            case(i_sqrt_in[7:3])
                0 : sqrt_out = 11'd508;
                1 : sqrt_out = 11'd500;
                2 : sqrt_out = 11'd493;
                3 : sqrt_out = 11'd486;
                4 : sqrt_out = 11'd479;
                5 : sqrt_out = 11'd472;
                6 : sqrt_out = 11'd466;
                7 : sqrt_out = 11'd460;
                8 : sqrt_out = 11'd455;
                9 : sqrt_out = 11'd449;
                10 : sqrt_out = 11'd444;
                11 : sqrt_out = 11'd439;
                12 : sqrt_out = 11'd434;
                13 : sqrt_out = 11'd429;
                14 : sqrt_out = 11'd424;
                15 : sqrt_out = 11'd420;
                16 : sqrt_out = 11'd415;
                17 : sqrt_out = 11'd411;
                18 : sqrt_out = 11'd407;
                19 : sqrt_out = 11'd403;
                20 : sqrt_out = 11'd399;
                21 : sqrt_out = 11'd395;
                22 : sqrt_out = 11'd392;
                23 : sqrt_out = 11'd388;
                24 : sqrt_out = 11'd385;
                25 : sqrt_out = 11'd381;
                26 : sqrt_out = 11'd378;
                27 : sqrt_out = 11'd375;
                28 : sqrt_out = 11'd372;
                29 : sqrt_out = 11'd369;
                30 : sqrt_out = 11'd366;
                31 : sqrt_out = 11'd363;

            endcase
        end
        else if(i_sqrt_in[7])begin
            case(i_sqrt_in[6:2])
                0 : sqrt_out = 11'd718;
                1 : sqrt_out = 11'd707;
                2 : sqrt_out = 11'd697;
                3 : sqrt_out = 11'd687;
                4 : sqrt_out = 11'd677;
                5 : sqrt_out = 11'd668;
                6 : sqrt_out = 11'd660;
                7 : sqrt_out = 11'd651;
                8 : sqrt_out = 11'd643;
                9 : sqrt_out = 11'd635;
                10 : sqrt_out = 11'd628;
                11 : sqrt_out = 11'd621;
                12 : sqrt_out = 11'd614;
                13 : sqrt_out = 11'd607;
                14 : sqrt_out = 11'd600;
                15 : sqrt_out = 11'd594;
                16 : sqrt_out = 11'd588;
                17 : sqrt_out = 11'd582;
                18 : sqrt_out = 11'd576;
                19 : sqrt_out = 11'd570;
                20 : sqrt_out = 11'd565;
                21 : sqrt_out = 11'd559;
                22 : sqrt_out = 11'd554;
                23 : sqrt_out = 11'd549;
                24 : sqrt_out = 11'd544;
                25 : sqrt_out = 11'd540;
                26 : sqrt_out = 11'd535;
                27 : sqrt_out = 11'd531;
                28 : sqrt_out = 11'd526;
                29 : sqrt_out = 11'd522;
                30 : sqrt_out = 11'd518;
                31 : sqrt_out = 11'd514;

            endcase
        end
        else if(i_sqrt_in[6])begin
            case(i_sqrt_in[5:1])
                0 : sqrt_out = 11'd1016;
                1 : sqrt_out = 11'd1000;
                2 : sqrt_out = 11'd986;
                3 : sqrt_out = 11'd972;
                4 : sqrt_out = 11'd958;
                5 : sqrt_out = 11'd945;
                6 : sqrt_out = 11'd933;
                7 : sqrt_out = 11'd921;
                8 : sqrt_out = 11'd910;
                9 : sqrt_out = 11'd899;
                10 : sqrt_out = 11'd888;
                11 : sqrt_out = 11'd878;
                12 : sqrt_out = 11'd868;
                13 : sqrt_out = 11'd858;
                14 : sqrt_out = 11'd849;
                15 : sqrt_out = 11'd840;
                16 : sqrt_out = 11'd831;
                17 : sqrt_out = 11'd823;
                18 : sqrt_out = 11'd815;
                19 : sqrt_out = 11'd807;
                20 : sqrt_out = 11'd799;
                21 : sqrt_out = 11'd791;
                22 : sqrt_out = 11'd784;
                23 : sqrt_out = 11'd777;
                24 : sqrt_out = 11'd770;
                25 : sqrt_out = 11'd763;
                26 : sqrt_out = 11'd757;
                27 : sqrt_out = 11'd750;
                28 : sqrt_out = 11'd744;
                29 : sqrt_out = 11'd738;
                30 : sqrt_out = 11'd732;
                31 : sqrt_out = 11'd726;

            endcase
        end
        else if(i_sqrt_in[5])begin
            case(i_sqrt_in[4:0])
                0 : sqrt_out = 11'd1448;
                1 : sqrt_out = 11'd1426;
                2 : sqrt_out = 11'd1404;
                3 : sqrt_out = 11'd1384;
                4 : sqrt_out = 11'd1365;
                5 : sqrt_out = 11'd1346;
                6 : sqrt_out = 11'd1328;
                7 : sqrt_out = 11'd1311;
                8 : sqrt_out = 11'd1295;
                9 : sqrt_out = 11'd1279;
                10 : sqrt_out = 11'd1264;
                11 : sqrt_out = 11'd1249;
                12 : sqrt_out = 11'd1234;
                13 : sqrt_out = 11'd1221;
                14 : sqrt_out = 11'd1207;
                15 : sqrt_out = 11'd1194;
                16 : sqrt_out = 11'd1182;
                17 : sqrt_out = 11'd1170;
                18 : sqrt_out = 11'd1158;
                19 : sqrt_out = 11'd1147;
                20 : sqrt_out = 11'd1136;
                21 : sqrt_out = 11'd1125;
                22 : sqrt_out = 11'd1114;
                23 : sqrt_out = 11'd1104;
                24 : sqrt_out = 11'd1094;
                25 : sqrt_out = 11'd1085;
                26 : sqrt_out = 11'd1075;
                27 : sqrt_out = 11'd1066;
                28 : sqrt_out = 11'd1057;
                29 : sqrt_out = 11'd1048;
                30 : sqrt_out = 11'd1040;
                31 : sqrt_out = 11'd1032;

            endcase
        end
        else sqrt_out = 11'd2047;
    end
endmodule
*/

module Inv_sqrt(  //better

	input [13:0] i_sqrt_in,

	output reg [10:0] sqrt_out 

    );

    // reg [10 : 0 ] sqrt_out;

    // assign o_inv_sqrt_out = sqrt_out; 

    always@(*)begin 

    if(i_sqrt_in[13])begin
    case(i_sqrt_in[12:8])
        0 : sqrt_out = 11'd90;
        1 : sqrt_out = 11'd89;
        2 : sqrt_out = 11'd87;
        3 : sqrt_out = 11'd86;
        4 : sqrt_out = 11'd85;
        5 : sqrt_out = 11'd84;
        6 : sqrt_out = 11'd83;
        7 : sqrt_out = 11'd81;
        8 : sqrt_out = 11'd80;
        9 : sqrt_out = 11'd79;
        10 : sqrt_out = 11'd79;
        11 : sqrt_out = 11'd78;
        12 : sqrt_out = 11'd77;
        13 : sqrt_out = 11'd76;
        14 : sqrt_out = 11'd75;
        15 : sqrt_out = 11'd74;
        16 : sqrt_out = 11'd73;
        17 : sqrt_out = 11'd73;
        18 : sqrt_out = 11'd72;
        19 : sqrt_out = 11'd71;
        20 : sqrt_out = 11'd71;
        21 : sqrt_out = 11'd70;
        22 : sqrt_out = 11'd69;
        23 : sqrt_out = 11'd69;
        24 : sqrt_out = 11'd68;
        25 : sqrt_out = 11'd67;
        26 : sqrt_out = 11'd67;
        27 : sqrt_out = 11'd66;
        28 : sqrt_out = 11'd66;
        29 : sqrt_out = 11'd65;
        30 : sqrt_out = 11'd65;
        31 : sqrt_out = 11'd64;

    endcase
    end

    else if(i_sqrt_in[12])begin
    case(i_sqrt_in[11:7])
        0 : sqrt_out = 11'd128;
        1 : sqrt_out = 11'd126;
        2 : sqrt_out = 11'd124;
        3 : sqrt_out = 11'd122;
        4 : sqrt_out = 11'd120;
        5 : sqrt_out = 11'd119;
        6 : sqrt_out = 11'd117;
        7 : sqrt_out = 11'd115;
        8 : sqrt_out = 11'd114;
        9 : sqrt_out = 11'd113;
        10 : sqrt_out = 11'd111;
        11 : sqrt_out = 11'd110;
        12 : sqrt_out = 11'd109;
        13 : sqrt_out = 11'd107;
        14 : sqrt_out = 11'd106;
        15 : sqrt_out = 11'd105;
        16 : sqrt_out = 11'd104;
        17 : sqrt_out = 11'd103;
        18 : sqrt_out = 11'd102;
        19 : sqrt_out = 11'd101;
        20 : sqrt_out = 11'd100;
        21 : sqrt_out = 11'd99;
        22 : sqrt_out = 11'd98;
        23 : sqrt_out = 11'd97;
        24 : sqrt_out = 11'd96;
        25 : sqrt_out = 11'd95;
        26 : sqrt_out = 11'd95;
        27 : sqrt_out = 11'd94;
        28 : sqrt_out = 11'd93;
        29 : sqrt_out = 11'd92;
        30 : sqrt_out = 11'd91;
        31 : sqrt_out = 11'd91;

    endcase
    end

    else if(i_sqrt_in[11])begin
    case(i_sqrt_in[10:6])
        0 : sqrt_out = 11'd181;
        1 : sqrt_out = 11'd178;
        2 : sqrt_out = 11'd175;
        3 : sqrt_out = 11'd173;
        4 : sqrt_out = 11'd170;
        5 : sqrt_out = 11'd168;
        6 : sqrt_out = 11'd166;
        7 : sqrt_out = 11'd163;
        8 : sqrt_out = 11'd161;
        9 : sqrt_out = 11'd159;
        10 : sqrt_out = 11'd158;
        11 : sqrt_out = 11'd156;
        12 : sqrt_out = 11'd154;
        13 : sqrt_out = 11'd152;
        14 : sqrt_out = 11'd150;
        15 : sqrt_out = 11'd149;
        16 : sqrt_out = 11'd147;
        17 : sqrt_out = 11'd146;
        18 : sqrt_out = 11'd144;
        19 : sqrt_out = 11'd143;
        20 : sqrt_out = 11'd142;
        21 : sqrt_out = 11'd140;
        22 : sqrt_out = 11'd139;
        23 : sqrt_out = 11'd138;
        24 : sqrt_out = 11'd136;
        25 : sqrt_out = 11'd135;
        26 : sqrt_out = 11'd134;
        27 : sqrt_out = 11'd133;
        28 : sqrt_out = 11'd132;
        29 : sqrt_out = 11'd131;
        30 : sqrt_out = 11'd130;
        31 : sqrt_out = 11'd129;

    endcase
    end

    else if(i_sqrt_in[10])begin
    case(i_sqrt_in[9:5])
        0 : sqrt_out = 11'd256;
        1 : sqrt_out = 11'd252;
        2 : sqrt_out = 11'd248;
        3 : sqrt_out = 11'd244;
        4 : sqrt_out = 11'd241;
        5 : sqrt_out = 11'd238;
        6 : sqrt_out = 11'd234;
        7 : sqrt_out = 11'd231;
        8 : sqrt_out = 11'd228;
        9 : sqrt_out = 11'd226;
        10 : sqrt_out = 11'd223;
        11 : sqrt_out = 11'd220;
        12 : sqrt_out = 11'd218;
        13 : sqrt_out = 11'd215;
        14 : sqrt_out = 11'd213;
        15 : sqrt_out = 11'd211;
        16 : sqrt_out = 11'd209;
        17 : sqrt_out = 11'd206;
        18 : sqrt_out = 11'd204;
        19 : sqrt_out = 11'd202;
        20 : sqrt_out = 11'd200;
        21 : sqrt_out = 11'd198;
        22 : sqrt_out = 11'd197;
        23 : sqrt_out = 11'd195;
        24 : sqrt_out = 11'd193;
        25 : sqrt_out = 11'd191;
        26 : sqrt_out = 11'd190;
        27 : sqrt_out = 11'd188;
        28 : sqrt_out = 11'd186;
        29 : sqrt_out = 11'd185;
        30 : sqrt_out = 11'd183;
        31 : sqrt_out = 11'd182;

    endcase
    end

    else if(i_sqrt_in[9])begin
    case(i_sqrt_in[8:4])
        0 : sqrt_out = 11'd362;
        1 : sqrt_out = 11'd356;
        2 : sqrt_out = 11'd351;
        3 : sqrt_out = 11'd346;
        4 : sqrt_out = 11'd341;
        5 : sqrt_out = 11'd336;
        6 : sqrt_out = 11'd332;
        7 : sqrt_out = 11'd327;
        8 : sqrt_out = 11'd323;
        9 : sqrt_out = 11'd319;
        10 : sqrt_out = 11'd316;
        11 : sqrt_out = 11'd312;
        12 : sqrt_out = 11'd308;
        13 : sqrt_out = 11'd305;
        14 : sqrt_out = 11'd301;
        15 : sqrt_out = 11'd298;
        16 : sqrt_out = 11'd295;
        17 : sqrt_out = 11'd292;
        18 : sqrt_out = 11'd289;
        19 : sqrt_out = 11'd286;
        20 : sqrt_out = 11'd284;
        21 : sqrt_out = 11'd281;
        22 : sqrt_out = 11'd278;
        23 : sqrt_out = 11'd276;
        24 : sqrt_out = 11'd273;
        25 : sqrt_out = 11'd271;
        26 : sqrt_out = 11'd268;
        27 : sqrt_out = 11'd266;
        28 : sqrt_out = 11'd264;
        29 : sqrt_out = 11'd262;
        30 : sqrt_out = 11'd260;
        31 : sqrt_out = 11'd258;

    endcase
    end

    else if(i_sqrt_in[8])begin
    case(i_sqrt_in[7:3])
        0 : sqrt_out = 11'd512;
        1 : sqrt_out = 11'd504;
        2 : sqrt_out = 11'd496;
        3 : sqrt_out = 11'd489;
        4 : sqrt_out = 11'd482;
        5 : sqrt_out = 11'd476;
        6 : sqrt_out = 11'd469;
        7 : sqrt_out = 11'd463;
        8 : sqrt_out = 11'd457;
        9 : sqrt_out = 11'd452;
        10 : sqrt_out = 11'd446;
        11 : sqrt_out = 11'd441;
        12 : sqrt_out = 11'd436;
        13 : sqrt_out = 11'd431;
        14 : sqrt_out = 11'd427;
        15 : sqrt_out = 11'd422;
        16 : sqrt_out = 11'd418;
        17 : sqrt_out = 11'd413;
        18 : sqrt_out = 11'd409;
        19 : sqrt_out = 11'd405;
        20 : sqrt_out = 11'd401;
        21 : sqrt_out = 11'd397;
        22 : sqrt_out = 11'd394;
        23 : sqrt_out = 11'd390;
        24 : sqrt_out = 11'd387;
        25 : sqrt_out = 11'd383;
        26 : sqrt_out = 11'd380;
        27 : sqrt_out = 11'd377;
        28 : sqrt_out = 11'd373;
        29 : sqrt_out = 11'd370;
        30 : sqrt_out = 11'd367;
        31 : sqrt_out = 11'd364;

    endcase
    end

    else if(i_sqrt_in[7])begin
    case(i_sqrt_in[6:2])
        0 : sqrt_out = 11'd724;
        1 : sqrt_out = 11'd713;
        2 : sqrt_out = 11'd702;
        3 : sqrt_out = 11'd692;
        4 : sqrt_out = 11'd682;
        5 : sqrt_out = 11'd673;
        6 : sqrt_out = 11'd664;
        7 : sqrt_out = 11'd655;
        8 : sqrt_out = 11'd647;
        9 : sqrt_out = 11'd639;
        10 : sqrt_out = 11'd632;
        11 : sqrt_out = 11'd624;
        12 : sqrt_out = 11'd617;
        13 : sqrt_out = 11'd610;
        14 : sqrt_out = 11'd603;
        15 : sqrt_out = 11'd597;
        16 : sqrt_out = 11'd591;
        17 : sqrt_out = 11'd585;
        18 : sqrt_out = 11'd579;
        19 : sqrt_out = 11'd573;
        20 : sqrt_out = 11'd568;
        21 : sqrt_out = 11'd562;
        22 : sqrt_out = 11'd557;
        23 : sqrt_out = 11'd552;
        24 : sqrt_out = 11'd547;
        25 : sqrt_out = 11'd542;
        26 : sqrt_out = 11'd537;
        27 : sqrt_out = 11'd533;
        28 : sqrt_out = 11'd528;
        29 : sqrt_out = 11'd524;
        30 : sqrt_out = 11'd520;
        31 : sqrt_out = 11'd516;

    endcase
    end

    else if(i_sqrt_in[6])begin
    case(i_sqrt_in[5:1])
        0 : sqrt_out = 11'd1024;
        1 : sqrt_out = 11'd1008;
        2 : sqrt_out = 11'd993;
        3 : sqrt_out = 11'd979;
        4 : sqrt_out = 11'd965;
        5 : sqrt_out = 11'd952;
        6 : sqrt_out = 11'd939;
        7 : sqrt_out = 11'd927;
        8 : sqrt_out = 11'd915;
        9 : sqrt_out = 11'd904;
        10 : sqrt_out = 11'd893;
        11 : sqrt_out = 11'd883;
        12 : sqrt_out = 11'd873;
        13 : sqrt_out = 11'd863;
        14 : sqrt_out = 11'd854;
        15 : sqrt_out = 11'd844;
        16 : sqrt_out = 11'd836;
        17 : sqrt_out = 11'd827;
        18 : sqrt_out = 11'd819;
        19 : sqrt_out = 11'd811;
        20 : sqrt_out = 11'd803;
        21 : sqrt_out = 11'd795;
        22 : sqrt_out = 11'd788;
        23 : sqrt_out = 11'd781;
        24 : sqrt_out = 11'd774;
        25 : sqrt_out = 11'd767;
        26 : sqrt_out = 11'd760;
        27 : sqrt_out = 11'd754;
        28 : sqrt_out = 11'd747;
        29 : sqrt_out = 11'd741;
        30 : sqrt_out = 11'd735;
        31 : sqrt_out = 11'd729;

    endcase
    end

    else if(i_sqrt_in[5])begin
    case(i_sqrt_in[4:0])
        0 : sqrt_out = 11'd1448;
        1 : sqrt_out = 11'd1426;
        2 : sqrt_out = 11'd1404;
        3 : sqrt_out = 11'd1384;
        4 : sqrt_out = 11'd1365;
        5 : sqrt_out = 11'd1346;
        6 : sqrt_out = 11'd1328;
        7 : sqrt_out = 11'd1311;
        8 : sqrt_out = 11'd1295;
        9 : sqrt_out = 11'd1279;
        10 : sqrt_out = 11'd1264;
        11 : sqrt_out = 11'd1249;
        12 : sqrt_out = 11'd1234;
        13 : sqrt_out = 11'd1221;
        14 : sqrt_out = 11'd1207;
        15 : sqrt_out = 11'd1194;
        16 : sqrt_out = 11'd1182;
        17 : sqrt_out = 11'd1170;
        18 : sqrt_out = 11'd1158;
        19 : sqrt_out = 11'd1147;
        20 : sqrt_out = 11'd1136;
        21 : sqrt_out = 11'd1125;
        22 : sqrt_out = 11'd1114;
        23 : sqrt_out = 11'd1104;
        24 : sqrt_out = 11'd1094;
        25 : sqrt_out = 11'd1085;
        26 : sqrt_out = 11'd1075;
        27 : sqrt_out = 11'd1066;
        28 : sqrt_out = 11'd1057;
        29 : sqrt_out = 11'd1048;
        30 : sqrt_out = 11'd1040;
        31 : sqrt_out = 11'd1032;

    endcase
    end

    else sqrt_out = 11'd2047;
    end
endmodule

