`timescale 1ns / 1ps

module vga_driver
(
input        I_clk_148M ,   // 1920x1080需要148.5MHz時鐘
input        I_rst_n , // 系統復位
input  [3:0] pp_led,   // 來自pingpong state machine的輸出球的LED位置，作為控制訊號
                       // ●○○○   ○●○○   ○○●○ ○○○●
output [4:0] O_red ,   // VGA紅色分量
output [5:0] O_green , // VGA綠色分量
output [4:0] O_blue ,  // VGA藍色分量
output       O_hs ,    // VGA行同步信號 active_low
output       O_vs      // VGA場同步信號 active_low
);

reg [4:0] O_red;   // VGA紅色(5 bits)分量
reg [5:0] O_green; // VGA綠色(6 bits)分量
reg [4:0] O_blue;  // VGA藍色(5 bits)分量
// 解析度?1920x1080時行時序各個參數定義
parameter C_H_SYNC_PULSE = 44 ,
          C_H_BACK_PORCH = 148 ,
          C_H_ACTIVE_TIME = 1920 , //這是LCD水平解析度
          C_H_FRONT_PORCH = 88 ,
          C_H_LINE_PERIOD = 2200 ; //44+148+1920+88=2200 
                                   //這是LCD螢幕一條水平線處理的時間
                                   //一共有1080條水平線

// 解析度?1920x1080時場時序各個參數定義
parameter C_V_SYNC_PULSE = 5 ,
          C_V_BACK_PORCH = 36 ,
          C_V_ACTIVE_TIME = 1080 , //這是LCD垂直解析度
          C_V_FRONT_PORCH = 4 ,
          C_V_FRAME_PERIOD = 1125 ; //5+36+1080+4=1125
                                    //這是LCD螢幕垂直方向處理的時間

// 一個128x128的圖像參數
parameter C_IMAGE_WIDTH = 128 ,
          C_IMAGE_HEIGHT = 128 ,
          C_IMAGE_PIX_NUM = 16384 ;

// 把1920x1080的螢幕，水平分成4個區域，每隔區域1920/4 = 480單位          
parameter C_COLOR_BAR_WIDTH = C_H_ACTIVE_TIME / 4 ;

reg [11:0] R_h_cnt ; // 行時序計數器
reg [11:0] R_v_cnt ; // 列時序計數器
reg        R_clk_25M ;
reg [13:0] R_rom_addr ; // ROM的地址
wire [15:0] W_rom_data ; // ROM中存儲的數據

reg [11:0] R_h_pos  ; //圖片在屏幕上顯示的水平位置，
                      //當它?0時，圖片貼緊屏幕的左邊緣
                              
reg [11:0] R_v_pos  ; //圖片在屏幕上顯示的垂直位置，
                      //當它?0時，圖片貼緊屏幕的上邊緣
                      

wire       W_active_flag ; // VGA螢幕動作旗標，
                           // 當這個信號?1時RGB的數據可以顯示在屏幕上

//////////////////////////////////////////////////////////////////
//功能：產生25MHz的像素時鐘 
//////////////////////////////////////////////////////////////////
/*  這是給640x480螢幕的時鐘，我是1920x1080螢幕，所以用不到
always @(posedge I_clk or negedge I_rst_n)
begin
if(!I_rst_n) R_clk_25M <= 1'b0 ;
else         R_clk_25M <= ~R_clk_25M ;
end
*/
//////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////
// 功能：產生行時序
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
// 功能：產生場時序
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
// 功能：把ROM中的圖片數據顯示到屏幕上
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
// 功能：使圖片移動的case設定 /*控制訊號來自pingpong state machine的輸出*/
//////////////////////////////////////////////////////////////////
//always@(posedge R_clk_25M or negedge I_rst_n)
always @(posedge I_clk_148M or negedge I_rst_n)
begin
if(!I_rst_n)
begin
R_h_pos <= 12'd00 ; //圖片位置水平初始值給00  
R_v_pos <= 12'd200 ;  //圖片位置垂直初始值給200  
end
else begin
case(pp_led)  //來自pingpong state machine的輸出
4'b1000: begin// 圖片在LCD螢幕最左邊的第1個區域  // ●○○○       
         R_h_pos <= 12'd10;  //(可以自己設定)
         end
4'b0100: begin// 圖片在LCD螢幕最左邊的第2個區域  // ○●○○
         R_h_pos <= 12'd10 + C_COLOR_BAR_WIDTH*1; 
         end
4'b0010: begin// 圖片在LCD螢幕最左邊的第3個區域  // ○○●○
         R_h_pos <= 12'd10 + C_COLOR_BAR_WIDTH*2; 
         end
4'b0001: begin// 圖片在LCD螢幕最左邊的第4個區域  // ○○○●
         R_h_pos <= 12'd10 + C_COLOR_BAR_WIDTH*3; 
         end
default: R_h_pos <= R_h_pos;
endcase
end
end

//這裡先把ROM的data取代掉，以紅色方形輸出在螢幕上
assign W_rom_data = 16'b1111_000000_00000; //直接設定RGB的數值(紅色)，
                                           //R(5bit)G(6bit)B(5bit)
/*
rom_image U_rom_image (
.clka(R_clk_25M), // input clka
.addra(R_rom_addr), // input [13 : 0] addra
.douta(W_rom_data) // output [15 : 0] douta
);
*/
endmodule
