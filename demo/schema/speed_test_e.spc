create or replace package speed_test_e is

	procedure gac_get(p_cnt pls_integer);

	procedure pv_get(p_cnt pls_integer);

	procedure dual_get(p_cnt pls_integer);

	procedure all_test(p_cnt pls_integer);

end speed_test_e;
/
