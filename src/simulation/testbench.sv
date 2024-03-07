`include "uvm_macros.svh"
import uvm_pkg::*;

class ps2_item extends uvm_sequence_item;

    rand bit kb_data;
    rand bit kb_clk;

    bit [15:0] buffer_out;
    bit error;

    `uvm_object_utils_begin(ps2_item)
		`uvm_field_int(kb_data, UVM_DEFAULT | UVM_BIN)
		`uvm_field_int(kb_clk, UVM_DEFAULT | UVM_BIN)
		`uvm_field_int(buffer_out, UVM_DEFAULT)
		`uvm_field_int(error, UVM_DEFAULT | UVM_BIN)
	`uvm_object_utils_end

    function new(string name = "ps2_item");
		super.new(name);
	endfunction
	
	virtual function string simple_print();
		return $sformatf(
			"kb_clk = %1b kb_data = %1b | output is irrelevant",
			kb_clk, kb_data
		);
	endfunction

endclass


class generator extends uvm_sequence;
	
	`uvm_object_utils(generator)

	function new(string name = "generator");
		super.new(name);
	endfunction

	int test_num = 10000;

	virtual task body();
		for(int i = 0; i < test_num; i++) begin
			ps2_item item = ps2_item::type_id::create("PS2_item");
			start_item(item);
			item.randomize();
			`uvm_info("GENERATOR", $sformatf("Item %0d/%0d created", i+1, test_num), UVM_LOW);
			item.print();
			finish_item(item);
		end
	endtask

endclass


class driver extends uvm_driver #(ps2_item);

	`uvm_component_utils(driver)

	function new(string name = "driver", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual ps2_interface vif;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db#(virtual ps2_interface)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("DRIVER", "No interface.")		
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);

		forever begin
			ps2_item item;
			seq_item_port.get_next_item(item);
			
			`uvm_info("DRIVER", $sformatf("%s", item.simple_print()), UVM_LOW)

			vif.kb_data <= item.kb_data;
			vif.kb_clk <= item.kb_clk;
			@(posedge vif.clk);

			seq_item_port.item_done();
		end
	endtask

endclass


class monitor extends uvm_monitor;

	`uvm_component_utils(monitor)

	function new(string name = "monitor", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual ps2_interface vif;
	uvm_analysis_port #(ps2_item) mon_analysis_port;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db#(virtual ps2_interface)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("MONITOR", "No interface.")
		mon_analysis_port = new("mon_analysis_port", this);
	endfunction


	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);

		@(posedge vif.clk);
		forever begin
			ps2_item item = ps2_item::type_id::create("PS2_item");
			@(posedge vif.clk);
			item.kb_data = vif.kb_data;
			item.kb_clk = vif.kb_clk;
			item.buffer_out = vif.buffer_out;
			item.error = vif.error;

			`uvm_info("MONITOR", $sformatf("%s", item.simple_print()), UVM_LOW)

			mon_analysis_port.write(item);
		end
	endtask

endclass


class agent extends uvm_agent;

	`uvm_component_utils(agent)

	function new(string name = "agent", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	driver d0;
	monitor m0;
	uvm_sequencer #(ps2_item) s0;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		d0 = driver::type_id::create("d0", this);
		m0 = monitor::type_id::create("m0", this);
		s0 = uvm_sequencer#(ps2_item)::type_id::create("s0", this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		d0.seq_item_port.connect(s0.seq_item_export);
	endfunction

endclass


class scoreboard extends uvm_scoreboard;

	`uvm_component_utils(scoreboard)

	function new(string name = "scoreboard", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	uvm_analysis_imp #(ps2_item, scoreboard) mon_analysis_imp;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		mon_analysis_imp = new("mon_analysis_imp", this);
	endfunction

	localparam IDLE_STATE       =    2'b00;
	localparam RECEIVING_STATE  =    2'b01;
	localparam CHECK_STATE      =    2'b10;
	localparam STOP_STATE       =    2'b11;

	bit error_out;
	bit [15:0] buffer_out;
	bit [1:0] state = IDLE_STATE;
	bit [3:0] cnt = 0;
	bit parity_bit;
	bit kb_clk_prev_val = 1;

	// compare with "QAs" impl of it
	virtual function write(ps2_item item);
		if(item.buffer_out == buffer_out && item.error == error_out)
			`uvm_info("SCOREBOARD", $sformatf("TEST PASSED!"), UVM_NONE)
		else
			`uvm_error("SCOREBOARD", $sformatf("TEST FAILED!	EXPECTED:  buffer_out = %h, error = %1b | GOT:  buffer_out = %h, error = %1b", buffer_out, error_out, item.buffer_out, item.error))
		if(kb_clk_prev_val == 1 && item.kb_clk == 0) begin
			// falling edge 
            `uvm_info("SCOREBOARD", $sformatf("FE DETECTED:   state: %d, kb_data: %b", state, item.kb_data), UVM_LOW)
			case(state) 
				IDLE_STATE: begin
					if(item.kb_data == 0) begin
						error_out = 0; 
						state = RECEIVING_STATE;
					end
				end

				RECEIVING_STATE: begin
					if(cnt % 8 == 0) begin
						parity_bit = item.kb_data;
					end else begin
						parity_bit = parity_bit ^ item.kb_data;
					end

					buffer_out[cnt] = item.kb_data;
					cnt = cnt + 1;
					if(cnt % 8 == 0) begin
						state = CHECK_STATE;
					end
				end

				CHECK_STATE: begin
					if(parity_bit ^ item.kb_data == 0) begin
						error_out = 1;
					end else begin
						error_out = 0;
					end

					state = STOP_STATE;
				end

				STOP_STATE: begin
					if(item.kb_data == 1) begin
						state = IDLE_STATE;
					end else begin
						error_out = 1;
						state = IDLE_STATE;
					end
				end
			endcase
		end

        kb_clk_prev_val = item.kb_clk;
	
	endfunction

endclass


class env extends uvm_env;
	
	`uvm_component_utils(env)

	function new(string name = "env", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	agent a0;
	scoreboard sb0;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		a0 = agent::type_id::create("a0", this);
		sb0 = scoreboard::type_id::create("sb0", this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);

		a0.m0.mon_analysis_port.connect(sb0.mon_analysis_imp);
	endfunction

endclass


class test extends uvm_test;

	`uvm_component_utils(test)

	function new(string name = "test", uvm_component parent = null);
		super.new(name, parent);
	endfunction

	virtual ps2_interface vif;

	env e0;
	generator g0;

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);

		if(!uvm_config_db#(virtual ps2_interface)::get(this, "", "ps2_vif", vif))
			`uvm_fatal("MONITOR", "No interface.")

		e0 = env::type_id::create("e0", this);
		g0 = generator::type_id::create("g0");
	endfunction

	virtual function void end_of_elaboration_phase(uvm_phase phase);
		uvm_top.print_topology();		
	endfunction

	virtual task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		
		vif.rst_n <= 0;
		#5 vif.rst_n <= 1;

		g0.start(e0.a0.s0);

		phase.drop_objection(this);
	endtask

endclass


interface ps2_interface(input bit clk);

	logic rst_n;
	logic kb_data;
	logic kb_clk;
	logic [15:0] buffer_out;
	logic error;

endinterface


module testbench;
	
	bit clk;

	ps2_interface dut_interface (
		.clk(clk)
	);

	ps2 dut (
		.clk(clk),
		.rst_n(dut_interface.rst_n),
		.kb_data(dut_interface.kb_data),
		.kb_clk(dut_interface.kb_clk),
		.buffer_out(dut_interface.buffer_out),
		.error(dut_interface.error)
	);

	initial begin
		clk = 0;
		forever begin
			#5 clk = ~clk;
		end
	end

	initial begin
		uvm_config_db#(virtual ps2_interface)::set(null, "*", "ps2_vif", dut_interface);
		run_test("test");
	end

endmodule
