create or replace package body attr_tagp_demo_b is

	procedure alink is
	begin
		p.h;
		src_b.link_proc;
		atr.id('id1');
		atr.class('c1 c2');
		atr.href('.');
		atr.target('_blank');
		atr.d('attr2=value2,attr3=value3');
		atr.d('year', to_char(sysdate, 'yyyy'));
		atr.checked(true);
		tgp.a('a link made by attr/tagx API', 'attr1=value1');
	end;

end attr_tagp_demo_b;
/
