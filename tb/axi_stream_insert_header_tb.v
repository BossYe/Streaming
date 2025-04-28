`timescale 1ns/1ns

module axi_stream_insert_header_tb;
    localparam DATA_WD      = 32;
    localparam DATA_BYTE_WD = DATA_WD / 8;
    localparam CLOCK_PERIOD = 10;
    localparam DATA_NUM = 5;

    reg clk;
    reg rst_n;

    // data_in 
    reg                        valid_in     ;
    reg   [DATA_WD-1 : 0]      data_in      ;
    reg   [DATA_BYTE_WD-1 : 0] keep_in      ;
    wire                       last_in      ;
    wire                       ready_in     ;

    // data_out
    wire                       valid_out    ;
    wire  [DATA_WD-1 : 0]      data_out     ;
    wire  [DATA_BYTE_WD-1 : 0] keep_out     ;
    wire                       last_out     ;
    reg                        ready_out    ;

    // header
    reg                        valid_insert ;
    reg   [DATA_WD-1 : 0]      header_insert;
    reg   [DATA_BYTE_WD-1 : 0] keep_insert  ;
    wire                       ready_insert ;


    // initial
    always #CLOCK_PERIOD clk = ~clk;

    initial begin
        // clk and rst_n (0 电平有效)
        clk          = 1'b0;
        rst_n        = 1'b0;

        //data_in 初始�?
        valid_in     = 1'b0;
        data_in      = 'd0;
        keep_in      = 'd0;

        ready_out    = 1'b1;

        //header 初始�?
        valid_insert   = 1'b0;
        header_insert  = 'd0;
        keep_insert    = 'd0;

        //2个周期后拉高
        #(2*CLOCK_PERIOD) rst_n = 1'b1;
    end  

    integer seed;
    initial begin
        seed = 123;
    end


    // 驱动header数据
    reg [2:0] sel;  
    initial begin
        forever begin
            @(negedge clk)begin
                header_insert = $random(seed);
                sel = $random(seed) % 5;
                case(sel)
                    0: keep_insert = 4'b1111;
                    1: keep_insert = 4'b0111;
                    2: keep_insert = 4'b0011;
                    3: keep_insert = 4'b0001;
                    4: keep_insert = 4'b0000;
                    default: keep_insert = 4'b0000;
                endcase
            end
        end
    end

    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            valid_insert <= 1'b0;
        end
        else begin
            valid_insert <= $random(seed) % 2;
        end
    end

    //驱动data_in数据
    reg [3:0] cnt = 0;

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n) cnt <= 'd0;
        else begin
            if(ready_in && valid_in) begin
                cnt <= cnt + 'd1;
            end
            else if (cnt == DATA_NUM) begin
                cnt <= 'd0;
            end
            else cnt <= cnt;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)  valid_in <= 1'b0;
        else begin
            if(ready_in) begin
                if(cnt <= 4) valid_in <= 1;
                else valid_in <= 0;
            end
            else valid_in <= valid_in;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)  data_in <= 'd0;
        else begin
            if(ready_in) begin
                if(cnt <= 4) begin
                    data_in <= $random(seed);
                end
            end
            else data_in <= data_in;
        end
    end  

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)  keep_in <= 'd0;
        else begin
            if(ready_in) begin
                if(cnt <= 3) keep_in <= 4'b1111;
                else if (cnt == 4) begin
                    //case($random($time) % 4)
                    //    0: keep_in = 4'b1111;
                    //    1: keep_in = 4'b1110;
                    //    2: keep_in = 4'b1100;
                    //    3: keep_in = 4'b1000;
                    //    default: keep_insert = 4'b0000;
                    //endcase
                    keep_in <= 4'b1000;                   
                end
            end
            else keep_in <= keep_in;
        end
    end    

    assign last_in = cnt == (DATA_NUM - 1) ? 1'b1: 1'b0;

    axi_stream_insert_header  # (
        .DATA_WD(DATA_WD),
        .DATA_BYTE_WD(DATA_BYTE_WD)
    ) dut_u0 (
        .clk                    (clk                ),
        .rst_n                  (rst_n              ),

        .valid_in               (valid_in           ),
        .data_in                (data_in            ),
        .keep_in                (keep_in            ),
        .last_in                (last_in           ),
        .ready_in               (ready_in           ),

        .valid_out              (valid_out          ),
        .data_out               (data_out           ),
        .keep_out               (keep_out           ),
        .last_out               (last_out           ),
        .ready_out              (ready_out          ),

        .valid_insert           (valid_insert       ),
        .header_insert          (header_insert      ),
        .keep_insert            (keep_insert        ),
        .ready_insert           (ready_insert       )
    );

endmodule