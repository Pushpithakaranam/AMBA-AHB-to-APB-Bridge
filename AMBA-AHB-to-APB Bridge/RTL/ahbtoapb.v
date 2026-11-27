// Code your design here
module ahb_to_apb_bridge (
    input        hclk,
    input        hresetn,

    // AHB inputs
    input        hwrite,
    input        hreadyin,
    input [1:0]  htrans,
    input [31:0] haddr,
    input [31:0] hwdata,

    // AHB outputs
    output reg [31:0] hrdata,
    output reg [1:0]  hresp,
    output reg        hreadyout,

    // APB outputs
    output reg        pwrite,
    output reg        penable,
    output reg [2:0]  psel,
    output reg [31:0] paddr,
    output reg [31:0] pwdata,

    // APB inputs
    input [31:0] prdata,
    input        pready,
    input        pslverr
);

    //====================================================
    // FSM STATES
    //====================================================

    parameter IDLE   = 2'b00;
    parameter SETUP  = 2'b01;
    parameter ACCESS = 2'b10;

    reg [1:0] state, next_state;


    //====================================================
    // AHB TRANSACTION REGISTERS
    //====================================================

    reg        write_reg;
    reg [31:0] addr_reg;
    reg [31:0] data_reg;


    //====================================================
    // AHB VALID TRANSFER
    //====================================================

    wire ahb_valid;

    assign ahb_valid =
            hreadyin &&
            ((htrans == 2'b10) ||       // NONSEQ
             (htrans == 2'b11));        // SEQ


    //====================================================
    // ADDRESS DECODER
    //====================================================

    always @(*) begin

        psel = 3'b000;

        if ((addr_reg >= 32'h8000_0000) &&
            (addr_reg <= 32'h83FF_FFFF)) begin

            psel = 3'b001;

        end

        else if ((addr_reg >= 32'h8400_0000) &&
                 (addr_reg <= 32'h87FF_FFFF)) begin

            psel = 3'b010;

        end

        else if ((addr_reg >= 32'h8800_0000) &&
                 (addr_reg <= 32'h8BFF_FFFF)) begin

            psel = 3'b100;

        end

        else begin

            psel = 3'b000;

        end

    end


    //====================================================
    // NEXT STATE LOGIC
    //====================================================

    always @(*) begin

        next_state = state;

        case (state)

            IDLE: begin

                if (ahb_valid)
                    next_state = SETUP;

                else
                    next_state = IDLE;

            end


            SETUP: begin

                next_state = ACCESS;

            end


            ACCESS: begin

                if (pready)
                    next_state = IDLE;

                else
                    next_state = ACCESS;

            end


            default: begin

                next_state = IDLE;

            end

        endcase

    end


    //====================================================
    // STATE REGISTER + AHB TRANSACTION LATCH
    //====================================================

    always @(posedge hclk or negedge hresetn) begin

        if (!hresetn) begin

            state     <= IDLE;

            write_reg <= 1'b0;
            addr_reg  <= 32'b0;
            data_reg  <= 32'b0;

        end

        else begin

            state <= next_state;


            // Capture AHB transaction

            if ((state == IDLE) && ahb_valid) begin

                write_reg <= hwrite;
                addr_reg  <= haddr;
                data_reg  <= hwdata;

            end

        end

    end


    //====================================================
    // OUTPUT LOGIC
    //====================================================

    always @(*) begin

        // Default values

        pwrite    = 1'b0;
        penable   = 1'b0;
        paddr     = addr_reg;
        pwdata    = data_reg;

        hrdata    = 32'b0;
        hresp     = 2'b00;
        hreadyout = 1'b0;


        case (state)

            //================================================
            // IDLE
            //================================================

            IDLE: begin

                pwrite    = 1'b0;
                penable   = 1'b0;

                hreadyout = 1'b1;

            end


            //================================================
            // APB SETUP PHASE
            //================================================

            SETUP: begin

                pwrite  = write_reg;
                penable = 1'b0;

                paddr   = addr_reg;
                pwdata  = data_reg;

                hreadyout = 1'b0;

            end


            //================================================
            // APB ACCESS PHASE
            //================================================

            ACCESS: begin

                pwrite  = write_reg;
                penable = 1'b1;

                paddr   = addr_reg;
                pwdata  = data_reg;


                // APB response

                hrdata = prdata;


                if (pready) begin

                    hreadyout = 1'b1;

                    if (pslverr)
                        hresp = 2'b01;       // ERROR

                    else
                        hresp = 2'b00;       // OKAY

                end

                else begin

                    hreadyout = 1'b0;
                    hresp     = 2'b00;

                end

            end


            default: begin

                pwrite    = 1'b0;
                penable   = 1'b0;
                hreadyout = 1'b1;

            end

        endcase

    end

endmodule