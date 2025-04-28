`timescale 1ns/1ns


module axi_stream_insert_header #(
    parameter DATA_WD = 32,
    parameter DATA_BYTE_WD = DATA_WD / 8
) (
    input                        clk,
    input                        rst_n,

    // AXI Stream input original data
    input                        valid_in,
    input   [DATA_WD-1 : 0]      data_in,
    input   [DATA_BYTE_WD-1 : 0] keep_in,
    input                        last_in,
    output                       ready_in,

    // AXI Stream output with header inserted
    output                       valid_out,
    output  [DATA_WD-1 : 0]      data_out,
    output  [DATA_BYTE_WD-1 : 0] keep_out,
    output                       last_out,
    input                        ready_out,

    // The header to be inserted to AXI Stream input
    input                        valid_insert,
    input   [DATA_WD-1 : 0]      header_insert,
    input   [DATA_BYTE_WD-1 : 0] keep_insert,
    output                       ready_insert
);


    reg [DATA_WD - 1 : 0]         header_insert_r ;
    reg [DATA_BYTE_WD - 1 : 0]    keep_insert_r   ;
    
    reg [DATA_WD - 1 : 0]         data_cat_r      ;
    reg [DATA_WD - 1 : 0]         data_buffer_r   ;
    reg                           first_in_r      ;

    reg [DATA_BYTE_WD-1 : 0]      keep_out_r       ;
    reg                           last_out_r       ;

    reg                           last_in_d1_r;

    reg                           ready_insert_r  ;
    reg                           ready_in_r      ;

    assign  ready_in = ready_in_r;
    assign  ready_insert = ready_insert_r;

    // 先接收 headr 信号
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n || last_out)begin
            ready_insert_r <= 1'b1;
        end
        else begin
            if(valid_insert && ready_insert)begin //握手一次成功后，拉低, 只接收1拍
                ready_insert_r <= 1'b0;
            end
            else begin
                ready_insert_r <= ready_insert_r;
            end
        end
    end

    // 存储 header 数据
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            header_insert_r <= 'd0;
            keep_insert_r <= 'd0;
        end
        else begin
            if(valid_insert && ready_insert) begin
                header_insert_r <= header_insert;
                keep_insert_r <= keep_insert;
            end
            else begin
                header_insert_r <= header_insert_r;
                keep_insert_r <= keep_insert_r;
            end
        end
    end


    //等待headr信号接收后，拉高data ready，准备接收数据；
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            ready_in_r <= 'd0;
        end
        else begin
            if(valid_insert && ready_insert) begin
                ready_in_r <= 1'b1;
            end
            else if (last_in) begin
                ready_in_r <= 1'b0;
            end
            else ready_in_r <= ready_in_r;
        end
    end

    //数据接收后直接拼接
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            data_cat_r <= 'd0;
            data_buffer_r <= 'd0;
        end
        else begin
            if(valid_in && ready_in && !first_in_r) begin
                case(keep_insert_r)
                    4'b1111: begin
                        data_cat_r <= header_insert_r;
                        data_buffer_r <= data_in;
                    end
                    4'b0111: begin
                        data_cat_r <= {header_insert_r[23:0],data_in[31:24]};
                        data_buffer_r <= {data_in[23:0],8'b0};
                    end 
                    4'b0011: begin
                        data_cat_r <= {header_insert_r[15:0],data_in[31:16]};
                        data_buffer_r <= {data_in[15:0],16'b0};
                    end
                    4'b0001: begin
                        data_cat_r <= {header_insert_r[7:0],data_in[31:8]};
                        data_buffer_r <= {data_in[7:0],24'b0};
                    end                      
                    4'b0000: begin 
                        data_cat_r <= data_in;
                        data_buffer_r <= 'd0;
                    end        
                    default: begin
                        data_cat_r <= 'd0;
                        data_buffer_r <= 'd0;
                    end
                endcase
            end
            else if (valid_in && ready_in && first_in_r) begin
                case(keep_insert_r)
                    4'b1111: begin
                        data_cat_r <= data_buffer_r;
                        data_buffer_r <= data_in;
                    end
                    4'b0111: begin
                        data_cat_r <= {data_buffer_r[31:8],data_in[31:24]};
                        data_buffer_r <= {data_in[23:0],8'b0};
                    end 
                    4'b0011: begin
                        data_cat_r <= {data_buffer_r[31:16],data_in[31:16]};
                        data_buffer_r <= {data_in[15:0],16'b0};
                    end
                    4'b0001: begin
                        data_cat_r <= {data_buffer_r[31:24],data_in[31:8]};
                        data_buffer_r <= {data_in[7:0],24'b0};
                    end                      
                    4'b0000: begin 
                        data_cat_r <= data_in;
                        data_buffer_r <= 'd0;
                    end        
                    default: begin
                        data_cat_r <= 'd0;
                        data_buffer_r <= 'd0;
                    end
                endcase
            end
            else if(last_in_d1_r) begin
                data_cat_r <= data_buffer_r;
            end
            else begin
                data_cat_r <= data_cat_r;
                data_buffer_r <= data_buffer_r;
            end
        end
    end

    //重置first_in;
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            first_in_r <= 1'b0;
        end
        else begin
            if(valid_in && ready_in && !last_in) begin
                first_in_r <= 1'b1;
            end
            else if(last_in) begin
                first_in_r <= 1'b0;
            end
            else first_in_r <= first_in_r;
        end
    end

    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            last_in_d1_r <= 1'b0;
            last_out_r <= 1'b0;
        end
        else begin
            if(last_in) begin
                casex({keep_insert_r,keep_in})
                    8'b0000_xxxx: last_out_r <= 1'b1;
                    8'b0001_1000: last_out_r <= 1'b1;
                    8'b0001_1100: last_out_r <= 1'b1;
                    8'b0001_1110: last_out_r <= 1'b1;
                    8'b0011_1000: last_out_r <= 1'b1;
                    8'b0011_1100: last_out_r <= 1'b1;
                    8'b0111_1000: last_out_r <= 1'b1;

                    8'b1111_xxxx: last_in_d1_r <= 1'b1;
                    8'b0111_1111: last_in_d1_r <= 1'b1;
                    8'b0111_1110: last_in_d1_r <= 1'b1;
                    8'b0111_1100: last_in_d1_r <= 1'b1;
                    8'b0011_1111: last_in_d1_r <= 1'b1;
                    8'b0011_1110: last_in_d1_r <= 1'b1;
                    8'b0001_1111: last_in_d1_r <= 1'b1;
                    default: begin
                        last_in_d1_r <= 1'b0;
                        last_out_r <= 1'b0;                         
                    end
                endcase
            end
            else if(last_in_d1_r) begin
                last_out_r <= 1'b1;
                last_in_d1_r <= 1'b0;
            end
            else begin
                last_in_d1_r <= 1'b0;
                last_out_r <= 1'b0;
            end           
        end
    end

    reg  [DATA_BYTE_WD - 1 : 0]  keep_last_r; 
    always@(posedge clk or negedge rst_n)begin
        if(!rst_n)begin
            keep_out_r <= 'd0;
            keep_last_r <= 'd0;
        end
        else begin
            if(valid_in && ready_in && !last_in) begin
                keep_out_r <= 4'b1111;
            end
            else if(last_in) begin
                case(keep_insert_r)
                    4'b0000: begin
                        keep_out_r <= keep_in;
                    end
                    4'b0001: begin
                        keep_out_r <= {1'b1,keep_in[3:1]};
                        keep_last_r <= keep_in << 3;
                    end
                    4'b0011: begin 
                        keep_out_r <= {2'b11,keep_in[3:2]};
                        keep_last_r <= keep_in << 2;
                    end
                    4'b0111: begin 
                        keep_out_r <= {3'b111,keep_in[3]};
                        keep_last_r <= keep_in << 1;
                    end
                    4'b1111: begin
                        keep_out_r <= 4'b1111;
                        keep_last_r <= keep_in;
                    end
                endcase
            end
            else if(last_in_d1_r) begin
                keep_out_r <= keep_last_r;
            end
            else begin
                keep_out_r <= 'd0;
                keep_last_r <= 'd0;
            end
        end
    end

    assign valid_out =  first_in_r || last_out || last_in_d1_r;
    assign keep_out = keep_out_r;
    assign last_out = last_out_r;
    assign data_out = ready_out ? data_cat_r : 'd0;
endmodule