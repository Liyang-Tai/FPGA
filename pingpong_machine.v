`timescale 1ns / 1ps

module pingpong_machine (
    input  clk ,
    input  rstn ,
    input  right_in,        //右邊按鈕
    input  left_in,         //左邊按鈕
    input  vga_done,        //來自VGA的完成訊號
    output [3:0] pp_LED,    //顯示乒乓球移動的LED
    output [1:0] right_LED,   //右邊分數對應2個LED
    output [1:0] left_LED    //左邊分數對應2個LED
    ) ;

    //machine state decode
    parameter IDLE  = 4'd0 ; //初始狀態
    parameter SL1   = 4'd1 ;
    parameter SL2   = 4'd2 ;
    parameter SL3   = 4'd3 ;
    parameter SL4   = 4'd4 ;
    parameter SL5   = 4'd5 ; //左邊贏球
    //
    parameter SR1   = 4'd6 ;
    parameter SR2   = 4'd7 ;
    parameter SR3   = 4'd8 ;
    parameter SR4   = 4'd9 ;
    parameter SR5   = 4'd10 ; //右邊贏球


    //machine variable
    reg [ 3 : 0 ]  st_next ;
    reg [ 3 : 0 ]  st_cur ;
    reg            SL1_en, SL2_en, SL3_en, SL4_en, SLwin_en,
                   SR1_en, SR2_en, SR3_en, SR4_en, SRwin_en;
    //
    wire           pp_led1_en = SL1_en | SR4_en; //這2種都是左邊第1顆LED亮
    wire           pp_led2_en = SL2_en | SR3_en; //這2種都是左邊第2顆LED亮
    wire           pp_led3_en = SL3_en | SR2_en; //這2種都是左邊第3顆LED亮
    wire           pp_led4_en = SL4_en | SR1_en; //這2種都是左邊第4顆LED亮
    wire[ 3 : 0 ]  pp_LED = {pp_led1_en, pp_led2_en, pp_led3_en, pp_led4_en};
    //(1) state transfer
    always @ ( posedge clk or negedge rstn ) begin
        if ( ! rstn ) begin
            st_cur <= 4'b0 ;
        end
        else if(vga_done) begin //收到VGA顯示完成的訊號再到下一個state
            st_cur <= st_next ;
        end
        else st_cur <= st_cur ;
    end

    //(2) state switch, using block assignment for combination-logic
    //all case items need to be displayed completely    
    always @ ( * ) begin
        //st_next = st_cur ;
        case ( st_cur )
            IDLE :begin
                if(left_in)       st_next = SL1;
                else if(right_in) st_next = SR1;
                else              st_next = st_cur; 
                end
            SL1 : begin//球左到右開始 ----->
                SL1_en = 1;
                st_next = SL2;
                end
            SL2 : begin
                SL2_en = 1;
                st_next = SL3;
                end
            SL3 : begin
                SL3_en = 1;
                st_next = SL4;
                end
            SL4 : begin
                SL4_en = 1;
                if(right_in)      st_next = SR2;  //右邊擊球
                else              st_next = SL5; //右邊沒擊球 左邊贏
                //st_next = st_next_w1;
                end
            SL5 : begin//左邊贏球
                SLwin_en = 1;
                st_next = IDLE;
                end
            SR1 : begin//球右到左開始 <-------
                SR1_en = 1;
                st_next = SR2;
                end
            SR2 : begin
                SR2_en = 1;
                st_next = SR3;
                end
            SR3 : begin
                SR3_en = 1;
                st_next = SR4;
                end
            SR4 : begin
                SR4_en = 1;
                if(left_in)       st_next = SL2; //左邊擊球
                else              st_next = SR5; //左邊沒擊球 右邊贏
                end
            SR5 : begin//右邊贏球
                SRwin_en = 1;
                st_next = IDLE;
                end
            default :  st_next = IDLE ;
        endcase
    end

    //(3) output logic 控制LED亮燈
    wire [ 1 : 0 ]   right_LED ;
    wire [ 1 : 0 ]   left_LED ;
    wire             right_winG, left_winG;
    reg  [ 3 : 0 ]   right_win_cont;
    reg  [ 3 : 0 ]   left_win_cont;
    
    always @ ( posedge clk or negedge rstn ) begin
        if ( ! rstn ) begin
            right_win_cont  <= 4'b0011;
            left_win_cont   <= 4'b0011;
        end
        else if (SRwin_en) begin //左移1位
            right_win_cont  <= {right_win_cont[2:0],right_win_cont[3]}; 
            left_win_cont   <= left_win_cont;
        end
        else if (SLwin_en) begin //左移1位
            right_win_cont  <= right_win_cont;
            left_win_cont   <= {left_win_cont[2:0],left_win_cont[3]}; //左移
        end
        else begin
            right_win_cont  <= right_win_cont;
            left_win_cont   <= left_win_cont;
        end
    end
    //驅動LED亮燈
    assign right_LED = right_win_cont[3:2];
    assign left_LED = left_win_cont[3:2];
    //贏球flag
    assign right_winG = (right_win_cont[3:2] == 2'b11);
    assign left_winG = (left_win_cont[3:2] == 2'b11);

endmodule 