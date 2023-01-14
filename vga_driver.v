`timescale 1ns / 1ps

module vga_driver
(
input        I_clk_148M ,   // 1920x1080�ݭn148.5MHz����
input        I_rst_n , // �t�δ_��
input  [3:0] pp_led,   // �Ӧ�pingpong state machine����X�y��LED��m�A�@������T��
                       // ��������   ��������   �������� ��������
output [4:0] O_red ,   // VGA������q
output [5:0] O_green , // VGA�����q
output [4:0] O_blue ,  // VGA�Ŧ���q
output       O_hs ,    // VGA��P�B�H�� active_low
output       O_vs      // VGA���P�B�H�� active_low
);

reg [4:0] O_red;   // VGA����(5 bits)���q
reg [5:0] O_green; // VGA���(6 bits)���q
reg [4:0] O_blue;  // VGA�Ŧ�(5 bits)���q
// �ѪR��?1920x1080�ɦ�ɧǦU�ӰѼƩw�q
parameter C_H_SYNC_PULSE = 44 ,
          C_H_BACK_PORCH = 148 ,
          C_H_ACTIVE_TIME = 1920 , //�o�OLCD�����ѪR��
          C_H_FRONT_PORCH = 88 ,
          C_H_LINE_PERIOD = 2200 ; //44+148+1920+88=2200 
                                   //�o�OLCD�ù��@�������u�B�z���ɶ�
                                   //�@�@��1080�������u

// �ѪR��?1920x1080�ɳ��ɧǦU�ӰѼƩw�q
parameter C_V_SYNC_PULSE = 5 ,
          C_V_BACK_PORCH = 36 ,
          C_V_ACTIVE_TIME = 1080 , //�o�OLCD�����ѪR��
          C_V_FRONT_PORCH = 4 ,
          C_V_FRAME_PERIOD = 1125 ; //5+36+1080+4=1125
                                    //�o�OLCD�ù�������V�B�z���ɶ�

// �@��128x128���Ϲ��Ѽ�
parameter C_IMAGE_WIDTH = 128 ,
          C_IMAGE_HEIGHT = 128 ,
          C_IMAGE_PIX_NUM = 16384 ;

// ��1920x1080���ù��A��������4�Ӱϰ�A�C�j�ϰ�1920/4 = 480���          
parameter C_COLOR_BAR_WIDTH = C_H_ACTIVE_TIME / 4 ;

reg [11:0] R_h_cnt ; // ��ɧǭp�ƾ�
reg [11:0] R_v_cnt ; // �C�ɧǭp�ƾ�
reg        R_clk_25M ;
reg [13:0] R_rom_addr ; // ROM���a�}
wire [15:0] W_rom_data ; // ROM���s�x���ƾ�

reg [11:0] R_h_pos  ; //�Ϥ��b�̹��W��ܪ�������m�A
                      //��?0�ɡA�Ϥ��K��̹�������t
                              
reg [11:0] R_v_pos  ; //�Ϥ��b�̹��W��ܪ�������m�A
                      //��?0�ɡA�Ϥ��K��̹����W��t
                      

wire       W_active_flag ; // VGA�ù��ʧ@�X�СA
                           // ��o�ӫH��?1��RGB���ƾڥi�H��ܦb�̹��W

//////////////////////////////////////////////////////////////////
//�\��G����25MHz���������� 
//////////////////////////////////////////////////////////////////
/*  �o�O��640x480�ù��������A�ڬO1920x1080�ù��A�ҥH�Τ���
always @(posedge I_clk or negedge I_rst_n)
begin
if(!I_rst_n) R_clk_25M <= 1'b0 ;
else         R_clk_25M <= ~R_clk_25M ;
end
*/
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
// �\��G���ͦ�ɧ�
//////////////////////////////////////////////////////////////////
//always @(posedge R_clk_25M or negedge I_rst_n)
always @(posedge I_clk_148M or negedge I_rst_n)
begin
if(!I_rst_n)
R_h_cnt <= 12'd0 ;
else if(R_h_cnt == C_H_LINE_PERIOD - 1'b1)
R_h_cnt <= 12'd0 ;
else
R_h_cnt <= R_h_cnt + 1'b1 ;
end

assign O_hs = (R_h_cnt < C_H_SYNC_PULSE) ? 1'b0 : 1'b1 ;
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
// �\��G���ͳ��ɧ�
//////////////////////////////////////////////////////////////////
//always @(posedge R_clk_25M or negedge I_rst_n)
always @(posedge I_clk_148M or negedge I_rst_n)
begin
if(!I_rst_n)
R_v_cnt <= 12'd0 ;
else if(R_v_cnt == C_V_FRAME_PERIOD - 1'b1)
R_v_cnt <= 12'd0 ;
else if(R_h_cnt == C_H_LINE_PERIOD - 1'b1)
R_v_cnt <= R_v_cnt + 1'b1 ;
else
R_v_cnt <= R_v_cnt ;
end

assign O_vs = (R_v_cnt < C_V_SYNC_PULSE) ? 1'b0 : 1'b1 ;
//////////////////////////////////////////////////////////////////

assign W_active_flag = (R_h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH )) &&
(R_h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + C_H_ACTIVE_TIME)) &&
(R_v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH )) &&
(R_v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + C_V_ACTIVE_TIME)) ;

//////////////////////////////////////////////////////////////////
// �\��G��ROM�����Ϥ��ƾ���ܨ�̹��W
//////////////////////////////////////////////////////////////////
//always @(posedge R_clk_25M or negedge I_rst_n)
always @(posedge I_clk_148M or negedge I_rst_n)
begin
if(!I_rst_n) R_rom_addr <= 14'd0 ;
else if(W_active_flag)
begin
if(R_h_cnt >= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_h_pos ) &&
R_h_cnt <= (C_H_SYNC_PULSE + C_H_BACK_PORCH + R_h_pos + C_IMAGE_WIDTH - 1'b1) &&
R_v_cnt >= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_v_pos ) &&
R_v_cnt <= (C_V_SYNC_PULSE + C_V_BACK_PORCH + R_v_pos + C_IMAGE_HEIGHT - 1'b1) )
begin
O_red <= W_rom_data[15:11] ;
O_green <= W_rom_data[10:5] ;
O_blue <= W_rom_data[4:0] ;
if(R_rom_addr == C_IMAGE_PIX_NUM - 1'b1)
R_rom_addr <= 14'd0 ;
else
R_rom_addr <= R_rom_addr + 1'b1 ;
end
else
begin
O_red <= 5'd0 ;
O_green <= 6'd0 ;
O_blue <= 5'd0 ;
R_rom_addr <= R_rom_addr ;
end
end
else
begin
O_red <= 5'd0 ;
O_green <= 6'd0 ;
O_blue <= 5'd0 ;
R_rom_addr <= R_rom_addr ;
end
end

//////////////////////////////////////////////////////////////////
// �\��G�ϹϤ����ʪ�case�]�w /*����T���Ӧ�pingpong state machine����X*/
//////////////////////////////////////////////////////////////////
//always@(posedge R_clk_25M or negedge I_rst_n)
always @(posedge I_clk_148M or negedge I_rst_n)
begin
if(!I_rst_n)
begin
R_h_pos <= 12'd00 ; //�Ϥ���m������l�ȵ�00  
R_v_pos <= 12'd200 ;  //�Ϥ���m������l�ȵ�200  
end
else begin
case(pp_led)  //�Ӧ�pingpong state machine����X
4'b1000: begin// �Ϥ��bLCD�ù��̥��䪺��1�Ӱϰ�  // ��������       
         R_h_pos <= 12'd10;  //(�i�H�ۤv�]�w)
         end
4'b0100: begin// �Ϥ��bLCD�ù��̥��䪺��2�Ӱϰ�  // ��������
         R_h_pos <= 12'd10 + C_COLOR_BAR_WIDTH*1; 
         end
4'b0010: begin// �Ϥ��bLCD�ù��̥��䪺��3�Ӱϰ�  // ��������
         R_h_pos <= 12'd10 + C_COLOR_BAR_WIDTH*2; 
         end
4'b0001: begin// �Ϥ��bLCD�ù��̥��䪺��4�Ӱϰ�  // ��������
         R_h_pos <= 12'd10 + C_COLOR_BAR_WIDTH*3; 
         end
default: R_h_pos <= R_h_pos;
endcase
end
end

//�o�̥���ROM��data���N���A�H�����ο�X�b�ù��W
assign W_rom_data = 16'b1111_000000_00000; //�����]�wRGB���ƭ�(����)�A
                                           //R(5bit)G(6bit)B(5bit)
/*
rom_image U_rom_image (
.clka(R_clk_25M), // input clka
.addra(R_rom_addr), // input [13 : 0] addra
.douta(W_rom_data) // output [15 : 0] douta
);
*/
endmodule
