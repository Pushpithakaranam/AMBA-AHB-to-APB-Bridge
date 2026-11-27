`timescale 1ns / 1ps

module tb_ahb_to_apb_bridge;

    //====================================================
    // CLOCK AND RESET
    //====================================================

    reg hclk;
    reg hresetn;

    initial begin
        hclk = 1'b0;
        forever #5 hclk = ~hclk;
    end

    //====================================================
    // AHB INPUTS
    //====================================================

    reg        hwrite;
    reg        hreadyin;
    reg [1:0]  htrans;
    reg [31:0] haddr;
    reg [31:0] hwdata;

    //====================================================
    // AHB OUTPUTS
    //====================================================

    wire [31:0] hrdata;
    wire [1:0]  hresp;
    wire        hreadyout;

    //====================================================
    // APB OUTPUTS
    //====================================================

    wire        pwrite;
    wire        penable;
    wire [2:0]  psel;
    wire [31:0] paddr;
    wire [31:0] pwdata;

    //====================================================
    // APB INPUTS
    //====================================================

    reg [31:0] prdata;
    reg        pready;
    reg        pslverr;


    //====================================================
    // DUT INSTANTIATION
    //====================================================

    ahb_to_apb_bridge DUT (

        .hclk       (hclk),
        .hresetn    (hresetn),

        .hwrite     (hwrite),
        .hreadyin   (hreadyin),
        .htrans     (htrans),
        .haddr      (haddr),
        .hwdata     (hwdata),

        .hrdata     (hrdata),
        .hresp      (hresp),
        .hreadyout  (hreadyout),

        .pwrite     (pwrite),
        .penable    (penable),
        .psel       (psel),
        .paddr      (paddr),
        .pwdata     (pwdata),

        .prdata     (prdata),
        .pready     (pready),
        .pslverr    (pslverr)
    );


    //====================================================
    // SIMPLE APB MEMORY
    //====================================================

    reg [31:0] memory [0:255];

    integer i;

    // APB slave model
    always @(posedge hclk) begin

        if (!hresetn) begin

            pready  <= 1'b0;
            prdata  <= 32'b0;
            pslverr <= 1'b0;

        end

        else begin

            pready  <= 1'b0;
            pslverr <= 1'b0;

            // APB ACCESS PHASE
            if (penable && (psel != 3'b000)) begin

                pready <= 1'b1;

                // WRITE
                if (pwrite) begin

                    memory[paddr[9:2]] <= pwdata;

                    $display(
                        "APB WRITE : PSEL=%b ADDR=%h DATA=%h",
                        psel,
                        paddr,
                        pwdata
                    );

                end

                // READ
                else begin

                    prdata <= memory[paddr[9:2]];

                    $display(
                        "APB READ  : PSEL=%b ADDR=%h DATA=%h",
                        psel,
                        paddr,
                        memory[paddr[9:2]]
                    );

                end

            end

        end

    end


    //====================================================
    // RESET TASK
    //====================================================

    task reset_dut;

    begin

        hresetn  = 1'b0;

        hwrite   = 1'b0;
        hreadyin = 1'b0;
        htrans   = 2'b00;
        haddr    = 32'b0;
        hwdata   = 32'b0;

        prdata   = 32'b0;
        pready   = 1'b0;
        pslverr  = 1'b0;

        repeat(3)
            @(posedge hclk);

        hresetn  = 1'b1;
        hreadyin = 1'b1;

        @(posedge hclk);

    end

    endtask


    //====================================================
    // AHB WRITE TASK
    //====================================================

    task ahb_write;

        input [31:0] address;
        input [31:0] data;

    begin

        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;        // NONSEQ
        haddr    = address;
        hwdata   = data;

        // Wait until bridge completes transfer

        while (hreadyout !== 1'b1)
            @(posedge hclk);

        @(posedge hclk);

        htrans = 2'b00;
        hwrite = 1'b0;

    end

    endtask


    //====================================================
    // AHB READ TASK
    //====================================================

    task ahb_read;

        input  [31:0] address;
        output [31:0] data;

    begin

        @(posedge hclk);

        hwrite   = 1'b0;
        hreadyin = 1'b1;
        htrans   = 2'b10;        // NONSEQ
        haddr    = address;
        hwdata   = 32'b0;

        // Wait until bridge completes transfer

        while (hreadyout !== 1'b1)
            @(posedge hclk);

        data = hrdata;

        @(posedge hclk);

        htrans = 2'b00;

    end

    endtask


    //====================================================
    // TC01 : RESET
    //====================================================

    task TC01_RESET;

    begin

        $display("");
        $display("==============================================");
        $display("TC01 : RESET");
        $display("==============================================");

        reset_dut;

        if (hreadyout == 1'b1) begin
            $display("TC01 PASS");
        end
        else begin
            $display("TC01 FAIL");
        end

    end

    endtask


    //====================================================
    // TC02 : SINGLE WRITE
    //====================================================

    task TC02_SINGLE_WRITE;

    begin

        $display("");
        $display("==============================================");
        $display("TC02 : SINGLE WRITE");
        $display("==============================================");

        reset_dut;

        ahb_write(
            32'h8400_0000,
            32'h0000_0029
        );

        if (memory[0] == 32'h0000_0029) begin

            $display("TC02 PASS");

        end
        else begin

            $display("TC02 FAIL");
            $display("Expected = 00000029");
            $display("Actual   = %h", memory[0]);

        end

    end

    endtask


    //====================================================
    // TC03 : SINGLE READ
    //====================================================

    task TC03_SINGLE_READ;

        reg [31:0] read_data;

    begin

        $display("");
        $display("==============================================");
        $display("TC03 : SINGLE READ");
        $display("==============================================");

        reset_dut;

        memory[0] = 32'h0000_0029;

        ahb_read(
            32'h8400_0000,
            read_data
        );

        if (read_data == 32'h0000_0029) begin

            $display("TC03 PASS");
            $display("Read Data = %h", read_data);

        end
        else begin

            $display("TC03 FAIL");
            $display("Expected = 00000029");
            $display("Actual   = %h", read_data);

        end

    end

    endtask


    //====================================================
    // TC04 : APB SLAVE 0
    //====================================================

    task TC04_SLAVE0;

    begin

        $display("");
        $display("==============================================");
        $display("TC04 : APB SLAVE 0 SELECTION");
        $display("==============================================");

        reset_dut;

        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;
        haddr    = 32'h8000_0000;
        hwdata   = 32'h1111_1111;

        @(posedge hclk);

        if (psel == 3'b001) begin
            $display("TC04 PASS : PSEL = %b", psel);
        end
        else begin
            $display("TC04 FAIL : PSEL = %b", psel);
        end

        while (hreadyout !== 1'b1)
            @(posedge hclk);

        htrans = 2'b00;
        hwrite = 1'b0;

    end

    endtask


    //====================================================
    // TC05 : APB SLAVE 1
    //====================================================

    task TC05_SLAVE1;

    begin

        $display("");
        $display("==============================================");
        $display("TC05 : APB SLAVE 1 SELECTION");
        $display("==============================================");

        reset_dut;

        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;
        haddr    = 32'h8400_0000;
        hwdata   = 32'h2222_2222;

        @(posedge hclk);

        if (psel == 3'b010) begin
            $display("TC05 PASS : PSEL = %b", psel);
        end
        else begin
            $display("TC05 FAIL : PSEL = %b", psel);
        end

        while (hreadyout !== 1'b1)
            @(posedge hclk);

        htrans = 2'b00;
        hwrite = 1'b0;

    end

    endtask


    //====================================================
    // TC06 : APB SLAVE 2
    //====================================================

    task TC06_SLAVE2;

    begin

        $display("");
        $display("==============================================");
        $display("TC06 : APB SLAVE 2 SELECTION");
        $display("==============================================");

        reset_dut;

        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;
        haddr    = 32'h8800_0000;
        hwdata   = 32'h3333_3333;

        @(posedge hclk);

        if (psel == 3'b100) begin
            $display("TC06 PASS : PSEL = %b", psel);
        end
        else begin
            $display("TC06 FAIL : PSEL = %b", psel);
        end

        while (hreadyout !== 1'b1)
            @(posedge hclk);

        htrans = 2'b00;
        hwrite = 1'b0;

    end

    endtask


    //====================================================
    // TC07 : INVALID ADDRESS
    //====================================================

    task TC07_INVALID_ADDRESS;

    begin

        $display("");
        $display("==============================================");
        $display("TC07 : INVALID ADDRESS");
        $display("==============================================");

        reset_dut;

        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;
        haddr    = 32'h9000_0000;
        hwdata   = 32'hAAAA_AAAA;

        @(posedge hclk);

        if (psel == 3'b000) begin

            $display("TC07 PASS : No APB slave selected");

        end
        else begin

            $display("TC07 FAIL : PSEL = %b", psel);

        end

        htrans = 2'b00;
        hwrite = 1'b0;

    end

    endtask


    //====================================================
    // TC08 : APB WAIT STATE
    //====================================================

    task TC08_WAIT_STATE;

    begin

        $display("");
        $display("==============================================");
        $display("TC08 : APB WAIT STATE");
        $display("==============================================");

        reset_dut;

        // First start an AHB write
        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;
        haddr    = 32'h8400_0008;
        hwdata   = 32'h5555_AAAA;

        // Wait for APB SETUP
        @(posedge hclk);

        // Wait for ACCESS
        @(posedge hclk);

        // Force APB wait state
        pready = 1'b0;

        if (penable == 1'b1) begin
            $display("APB ACCESS phase detected");
        end

        // Keep APB waiting for 3 clocks
        repeat(3)
            @(posedge hclk);

        // Complete APB transfer
        pready = 1'b1;

        @(posedge hclk);

        pready = 1'b0;

        while (hreadyout !== 1'b1)
            @(posedge hclk);

        htrans = 2'b00;
        hwrite = 1'b0;

        $display("TC08 PASS : Wait state tested");

    end

    endtask


    //====================================================
    // TC09 : APB ERROR
    //====================================================

    task TC09_APB_ERROR;

    begin

        $display("");
        $display("==============================================");
        $display("TC09 : APB ERROR");
        $display("==============================================");

        reset_dut;

        @(posedge hclk);

        hwrite   = 1'b1;
        hreadyin = 1'b1;
        htrans   = 2'b10;
        haddr    = 32'h8400_0010;
        hwdata   = 32'hDEAD_BEEF;

        // Wait for ACCESS
        wait(penable == 1'b1);

        // Generate APB error
        pready  = 1'b1;
        pslverr = 1'b1;

        @(posedge hclk);

        if (hresp == 2'b01) begin

            $display("TC09 PASS : HRESP = ERROR");

        end
        else begin

            $display("TC09 FAIL : HRESP = %b", hresp);

        end

        pready  = 1'b0;
        pslverr = 1'b0;

        htrans = 2'b00;
        hwrite = 1'b0;

    end

    endtask


    //====================================================
    // TC10 : BACK-TO-BACK WRITE/READ
    //====================================================

    task TC10_BACK_TO_BACK;

        reg [31:0] read_data;

    begin

        $display("");
        $display("==============================================");
        $display("TC10 : BACK-TO-BACK WRITE / READ");
        $display("==============================================");

        reset_dut;

        // WRITE

        ahb_write(
            32'h8400_0020,
            32'h1234_5678
        );

        // READ

        ahb_read(
            32'h8400_0020,
            read_data
        );

        if (read_data == 32'h1234_5678) begin

            $display("TC10 PASS");
            $display("Read Data = %h", read_data);

        end
        else begin

            $display("TC10 FAIL");
            $display("Expected = 12345678");
            $display("Actual   = %h", read_data);

        end

    end

    endtask


    //====================================================
    // INITIAL BLOCK
    //====================================================

    initial begin

        // Initialize memory

        for (i = 0; i < 256; i = i + 1)
            memory[i] = 32'b0;


        // Initial values

        hresetn  = 1'b0;
        hwrite   = 1'b0;
        hreadyin = 1'b0;
        htrans   = 2'b00;
        haddr    = 32'b0;
        hwdata   = 32'b0;

        prdata   = 32'b0;
        pready   = 1'b0;
        pslverr  = 1'b0;


        //================================================
        // RUN ALL TEST CASES
        //================================================

        TC01_RESET();

        TC02_SINGLE_WRITE();

        TC03_SINGLE_READ();

        TC04_SLAVE0();

        TC05_SLAVE1();

        TC06_SLAVE2();

        TC07_INVALID_ADDRESS();

        TC08_WAIT_STATE();

        TC09_APB_ERROR();

        TC10_BACK_TO_BACK();


        //================================================
        // SIMULATION END
        //================================================

        $display("");
        $display("**********************************************");
        $display("*                                            *");
        $display("*   AHB TO APB BRIDGE SIMULATION COMPLETE   *");
        $display("*                                            *");
        $display("**********************************************");
        $display("");

        #50;

        $finish;

    end


    //====================================================
    // WAVEFORM
    //====================================================

    initial begin

        $dumpfile("ahb_to_apb_bridge.vcd");
        $dumpvars(0, tb_ahb_to_apb_bridge);

    end

endmodule