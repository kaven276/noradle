create or replace package msg_b is

	procedure print_items;

	procedure sendout_single;
	procedure sendout_batch;

	procedure say_something;

	procedure resp_oper_result;
	procedure compute_callout;
	procedure compute;

	procedure direct_sendout;
	procedure direct_callout;
	procedure multiple_callout;
	procedure multiple_callout_easy_resp;

	procedure sync_sendout;

end msg_b;
/
