-- Strings.
SELECT '""'::json;				-- OK.
SELECT $$''$$::json;			-- ERROR, single quotes are not allowed
SELECT '"abc"'::json;			-- OK
SELECT '"abc'::json;			-- ERROR, quotes not closed
SELECT '"abc
def"'::json;					-- ERROR, unescaped newline in string constant
SELECT '"\n\"\\"'::json;		-- OK, legal escapes
SELECT '"\v"'::json;			-- ERROR, not a valid JSON escape
-- see json_encoding test for input with unicode escapes

-- Numbers.
SELECT '1'::json;				-- OK
SELECT '0'::json;				-- OK
SELECT '01'::json;				-- ERROR, not valid according to JSON spec
SELECT '0.1'::json;				-- OK
SELECT '9223372036854775808'::json;	-- OK, even though it's too large for int8
SELECT '1e100'::json;			-- OK
SELECT '1.3e100'::json;			-- OK
SELECT '1f2'::json;				-- ERROR
SELECT '0.x1'::json;			-- ERROR
SELECT '1.3ex100'::json;		-- ERROR

-- Arrays.
SELECT '[]'::json;				-- OK
SELECT '[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]'::json;  -- OK
SELECT '[1,2]'::json;			-- OK
SELECT '[1,2,]'::json;			-- ERROR, trailing comma
SELECT '[1,2'::json;			-- ERROR, no closing bracket
SELECT '[1,[2]'::json;			-- ERROR, no closing bracket

-- Objects.
SELECT '{}'::json;				-- OK
SELECT '{"abc"}'::json;			-- ERROR, no value
SELECT '{"abc":1}'::json;		-- OK
SELECT '{1:"abc"}'::json;		-- ERROR, keys must be strings
SELECT '{"abc",1}'::json;		-- ERROR, wrong separator
SELECT '{"abc"=1}'::json;		-- ERROR, totally wrong separator
SELECT '{"abc"::1}'::json;		-- ERROR, another wrong separator
SELECT '{"abc":1,"def":2,"ghi":[3,4],"hij":{"klm":5,"nop":[6]}}'::json; -- OK
SELECT '{"abc":1:2}'::json;		-- ERROR, colon in wrong spot
SELECT '{"abc":1,3}'::json;		-- ERROR, no value

-- Recursion.
SET max_stack_depth = '100kB';
SELECT repeat('[', 10000)::json;
SELECT repeat('{"a":', 10000)::json;
RESET max_stack_depth;

-- Miscellaneous stuff.
SELECT 'true'::json;			-- OK
SELECT 'false'::json;			-- OK
SELECT 'null'::json;			-- OK
SELECT ' true '::json;			-- OK, even with extra whitespace
SELECT 'true false'::json;		-- ERROR, too many values
SELECT 'true, false'::json;		-- ERROR, too many values
SELECT 'truf'::json;			-- ERROR, not a keyword
SELECT 'trues'::json;			-- ERROR, not a keyword
SELECT ''::json;				-- ERROR, no value
SELECT '    '::json;			-- ERROR, no value

--constructors
-- array_to_json

SELECT array_to_json(array(select 1 as a));
SELECT array_to_json(array_agg(q),false) from (select x as b, x * 2 as c from generate_series(1,3) x) q;
SELECT array_to_json(array_agg(q),true) from (select x as b, x * 2 as c from generate_series(1,3) x) q;
SELECT array_to_json(array_agg(q),false)
  FROM ( SELECT $$a$$ || x AS b, y AS c,
               ARRAY[ROW(x.*,ARRAY[1,2,3]),
               ROW(y.*,ARRAY[4,5,6])] AS z
         FROM generate_series(1,2) x,
              generate_series(4,5) y) q;
SELECT array_to_json(array_agg(x),false) from generate_series(5,10) x;
SELECT array_to_json('{{1,5},{99,100}}'::int[]);

-- row_to_json
SELECT row_to_json(row(1,'foo'));

SELECT row_to_json(q)
FROM (SELECT $$a$$ || x AS b,
         y AS c,
         ARRAY[ROW(x.*,ARRAY[1,2,3]),
               ROW(y.*,ARRAY[4,5,6])] AS z
      FROM generate_series(1,2) x,
           generate_series(4,5) y) q;

SELECT row_to_json(q,true)
FROM (SELECT $$a$$ || x AS b,
         y AS c,
         ARRAY[ROW(x.*,ARRAY[1,2,3]),
               ROW(y.*,ARRAY[4,5,6])] AS z
      FROM generate_series(1,2) x,
           generate_series(4,5) y) q;

CREATE TEMP TABLE rows AS
SELECT x, 'txt' || x as y
FROM generate_series(1,3) AS x;

SELECT row_to_json(q,true)
FROM rows q;

SELECT row_to_json(row((select array_agg(x) as d from generate_series(5,10) x)),false);

-- anyarray column

select to_json(histogram_bounds) histogram_bounds
from pg_stats
where attname = 'tmplname' and tablename = 'pg_pltemplate';

-- to_json, timestamps

select to_json(timestamp '2014-05-28 12:22:35.614298');

BEGIN;
SET LOCAL TIME ZONE 10.5;
select to_json(timestamptz '2014-05-28 12:22:35.614298-04');
SET LOCAL TIME ZONE -8;
select to_json(timestamptz '2014-05-28 12:22:35.614298-04');
COMMIT;

select to_json(date '2014-05-28');

select to_json(date 'Infinity');
select to_json(date '-Infinity');
select to_json(timestamp 'Infinity');
select to_json(timestamp '-Infinity');
select to_json(timestamptz 'Infinity');
select to_json(timestamptz '-Infinity');

--json_agg

SELECT json_agg(q)
  FROM ( SELECT $$a$$ || x AS b, y AS c,
               ARRAY[ROW(x.*,ARRAY[1,2,3]),
               ROW(y.*,ARRAY[4,5,6])] AS z
         FROM generate_series(1,2) x,
              generate_series(4,5) y) q;

SELECT json_agg(q ORDER BY x, y)
  FROM rows q;

UPDATE rows SET x = NULL WHERE x = 1;

SELECT json_agg(q ORDER BY x NULLS FIRST, y)
  FROM rows q;

-- non-numeric output
SELECT row_to_json(q)
FROM (SELECT 'NaN'::float8 AS "float8field") q;

SELECT row_to_json(q)
FROM (SELECT 'Infinity'::float8 AS "float8field") q;

SELECT row_to_json(q)
FROM (SELECT '-Infinity'::float8 AS "float8field") q;

-- json input
SELECT row_to_json(q)
FROM (SELECT '{"a":1,"b": [2,3,4,"d","e","f"],"c":{"p":1,"q":2}}'::json AS "jsonfield") q;


-- json extraction functions

CREATE TEMP TABLE test_json (
       json_type text,
       test_json json
);

INSERT INTO test_json VALUES
('scalar','"a scalar"'),
('array','["zero", "one","two",null,"four","five", [1,2,3],{"f1":9}]'),
('object','{"field1":"val1","field2":"val2","field3":null, "field4": 4, "field5": [1,2,3], "field6": {"f1":9}}');

SELECT test_json -> 'x'
FROM test_json
WHERE json_type = 'scalar';

SELECT test_json -> 'x'
FROM test_json
WHERE json_type = 'array';

SELECT test_json -> 'x'
FROM test_json
WHERE json_type = 'object';

SELECT test_json->'field2'
FROM test_json
WHERE json_type = 'object';

SELECT test_json->>'field2'
FROM test_json
WHERE json_type = 'object';

SELECT test_json -> 2
FROM test_json
WHERE json_type = 'scalar';

SELECT test_json -> 2
FROM test_json
WHERE json_type = 'array';

SELECT test_json -> -1
FROM test_json
WHERE json_type = 'array';

SELECT test_json -> 2
FROM test_json
WHERE json_type = 'object';

SELECT test_json->>2
FROM test_json
WHERE json_type = 'array';

SELECT test_json ->> 6 FROM test_json WHERE json_type = 'array';
SELECT test_json ->> 7 FROM test_json WHERE json_type = 'array';

SELECT test_json ->> 'field4' FROM test_json WHERE json_type = 'object';
SELECT test_json ->> 'field5' FROM test_json WHERE json_type = 'object';
SELECT test_json ->> 'field6' FROM test_json WHERE json_type = 'object';

SELECT json_object_keys(test_json)
FROM test_json
WHERE json_type = 'scalar';

SELECT json_object_keys(test_json)
FROM test_json
WHERE json_type = 'array';

SELECT json_object_keys(test_json)
FROM test_json
WHERE json_type = 'object';

-- test extending object_keys resultset - initial resultset size is 256

select count(*) from
    (select json_object_keys(json_object(array_agg(g)))
     from (select unnest(array['f'||n,n::text])as g
           from generate_series(1,300) as n) x ) y;

-- nulls

select (test_json->'field3') is null as expect_false
from test_json
where json_type = 'object';

select (test_json->>'field3') is null as expect_true
from test_json
where json_type = 'object';

select (test_json->3) is null as expect_false
from test_json
where json_type = 'array';

select (test_json->>3) is null as expect_true
from test_json
where json_type = 'array';

-- corner cases

select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json -> null::text;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json -> null::int;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json -> 1;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json -> -1;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json -> 'z';
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json -> '';
select '[{"b": "c"}, {"b": "cc"}]'::json -> 1;
select '[{"b": "c"}, {"b": "cc"}]'::json -> 3;
select '[{"b": "c"}, {"b": "cc"}]'::json -> 'z';
select '{"a": "c", "b": null}'::json -> 'b';
select '"foo"'::json -> 1;
select '"foo"'::json -> 'z';

select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json ->> null::text;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json ->> null::int;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json ->> 1;
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json ->> 'z';
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json ->> '';
select '[{"b": "c"}, {"b": "cc"}]'::json ->> 1;
select '[{"b": "c"}, {"b": "cc"}]'::json ->> 3;
select '[{"b": "c"}, {"b": "cc"}]'::json ->> 'z';
select '{"a": "c", "b": null}'::json ->> 'b';
select '"foo"'::json ->> 1;
select '"foo"'::json ->> 'z';

-- array length

SELECT json_array_length('[1,2,3,{"f1":1,"f2":[5,6]},4]');

SELECT json_array_length('[]');

SELECT json_array_length('{"f1":1,"f2":[5,6]}');

SELECT json_array_length('4');

-- each

select json_each('{"f1":[1,2,3],"f2":{"f3":1},"f4":null}');
select * from json_each('{"f1":[1,2,3],"f2":{"f3":1},"f4":null,"f5":99,"f6":"stringy"}') q;

select json_each_text('{"f1":[1,2,3],"f2":{"f3":1},"f4":null,"f5":"null"}');
select * from json_each_text('{"f1":[1,2,3],"f2":{"f3":1},"f4":null,"f5":99,"f6":"stringy"}') q;

-- extract_path, extract_path_as_text

select json_extract_path('{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}','f4','f6');
select json_extract_path('{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}','f2');
select json_extract_path('{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}','f2',0::text);
select json_extract_path('{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}','f2',1::text);
select json_extract_path_text('{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}','f4','f6');
select json_extract_path_text('{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}','f2');
select json_extract_path_text('{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}','f2',0::text);
select json_extract_path_text('{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}','f2',1::text);

-- extract_path nulls

select json_extract_path('{"f2":{"f3":1},"f4":{"f5":null,"f6":"stringy"}}','f4','f5') is null as expect_false;
select json_extract_path_text('{"f2":{"f3":1},"f4":{"f5":null,"f6":"stringy"}}','f4','f5') is null as expect_true;
select json_extract_path('{"f2":{"f3":1},"f4":[0,1,2,null]}','f4','3') is null as expect_false;
select json_extract_path_text('{"f2":{"f3":1},"f4":[0,1,2,null]}','f4','3') is null as expect_true;

-- extract_path operators

select '{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}'::json#>array['f4','f6'];
select '{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}'::json#>array['f2'];
select '{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}'::json#>array['f2','0'];
select '{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}'::json#>array['f2','1'];

select '{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}'::json#>>array['f4','f6'];
select '{"f2":{"f3":1},"f4":{"f5":99,"f6":"stringy"}}'::json#>>array['f2'];
select '{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}'::json#>>array['f2','0'];
select '{"f2":["f3",1],"f4":{"f5":99,"f6":"stringy"}}'::json#>>array['f2','1'];

-- corner cases for same
select '{"a": {"b":{"c": "foo"}}}'::json #> '{}';
select '[1,2,3]'::json #> '{}';
select '"foo"'::json #> '{}';
select '42'::json #> '{}';
select 'null'::json #> '{}';
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a'];
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a', null];
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a', ''];
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a','b'];
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a','b','c'];
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a','b','c','d'];
select '{"a": {"b":{"c": "foo"}}}'::json #> array['a','z','c'];
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json #> array['a','1','b'];
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json #> array['a','z','b'];
select '[{"b": "c"}, {"b": "cc"}]'::json #> array['1','b'];
select '[{"b": "c"}, {"b": "cc"}]'::json #> array['z','b'];
select '[{"b": "c"}, {"b": null}]'::json #> array['1','b'];
select '"foo"'::json #> array['z'];
select '42'::json #> array['f2'];
select '42'::json #> array['0'];

select '{"a": {"b":{"c": "foo"}}}'::json #>> '{}';
select '[1,2,3]'::json #>> '{}';
select '"foo"'::json #>> '{}';
select '42'::json #>> '{}';
select 'null'::json #>> '{}';
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a'];
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a', null];
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a', ''];
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a','b'];
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a','b','c'];
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a','b','c','d'];
select '{"a": {"b":{"c": "foo"}}}'::json #>> array['a','z','c'];
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json #>> array['a','1','b'];
select '{"a": [{"b": "c"}, {"b": "cc"}]}'::json #>> array['a','z','b'];
select '[{"b": "c"}, {"b": "cc"}]'::json #>> array['1','b'];
select '[{"b": "c"}, {"b": "cc"}]'::json #>> array['z','b'];
select '[{"b": "c"}, {"b": null}]'::json #>> array['1','b'];
select '"foo"'::json #>> array['z'];
select '42'::json #>> array['f2'];
select '42'::json #>> array['0'];

-- array_elements

select json_array_elements('[1,true,[1,[2,3]],null,{"f1":1,"f2":[7,8,9]},false,"stringy"]');
select * from json_array_elements('[1,true,[1,[2,3]],null,{"f1":1,"f2":[7,8,9]},false,"stringy"]') q;
select json_array_elements_text('[1,true,[1,[2,3]],null,{"f1":1,"f2":[7,8,9]},false,"stringy"]');
select * from json_array_elements_text('[1,true,[1,[2,3]],null,{"f1":1,"f2":[7,8,9]},false,"stringy"]') q;

-- populate_record
create type jpop as (a text, b int, c timestamp);

select * from json_populate_record(null::jpop,'{"a":"blurfl","x":43.2}') q;
select * from json_populate_record(row('x',3,'2012-12-31 15:30:56')::jpop,'{"a":"blurfl","x":43.2}') q;

select * from json_populate_record(null::jpop,'{"a":"blurfl","x":43.2}') q;
select * from json_populate_record(row('x',3,'2012-12-31 15:30:56')::jpop,'{"a":"blurfl","x":43.2}') q;

select * from json_populate_record(null::jpop,'{"a":[100,200,false],"x":43.2}') q;
select * from json_populate_record(row('x',3,'2012-12-31 15:30:56')::jpop,'{"a":[100,200,false],"x":43.2}') q;
select * from json_populate_record(row('x',3,'2012-12-31 15:30:56')::jpop,'{"c":[100,200,false],"x":43.2}') q;

-- populate_recordset

select * from json_populate_recordset(null::jpop,'[{"a":"blurfl","x":43.2},{"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(row('def',99,null)::jpop,'[{"a":"blurfl","x":43.2},{"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(null::jpop,'[{"a":"blurfl","x":43.2},{"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(row('def',99,null)::jpop,'[{"a":"blurfl","x":43.2},{"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(row('def',99,null)::jpop,'[{"a":[100,200,300],"x":43.2},{"a":{"z":true},"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(row('def',99,null)::jpop,'[{"c":[100,200,300],"x":43.2},{"a":{"z":true},"b":3,"c":"2012-01-20 10:42:53"}]') q;

create type jpop2 as (a int, b json, c int, d int);
select * from json_populate_recordset(null::jpop2, '[{"a":2,"c":3,"b":{"z":4},"d":6}]') q;

select * from json_populate_recordset(null::jpop,'[{"a":"blurfl","x":43.2},{"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(row('def',99,null)::jpop,'[{"a":"blurfl","x":43.2},{"b":3,"c":"2012-01-20 10:42:53"}]') q;
select * from json_populate_recordset(row('def',99,null)::jpop,'[{"a":[100,200,300],"x":43.2},{"a":{"z":true},"b":3,"c":"2012-01-20 10:42:53"}]') q;

--json_typeof() function
select value, json_typeof(value)
  from (values (json '123.4'),
               (json '-1'),
               (json '"foo"'),
               (json 'true'),
               (json 'false'),
               (json 'null'),
               (json '[1, 2, 3]'),
               (json '[]'),
               (json '{"x":"foo", "y":123}'),
               (json '{}'),
               (NULL::json))
      as data(value);

-- json_build_array, json_build_object, json_object_agg

SELECT json_build_array('a',1,'b',1.2,'c',true,'d',null,'e',json '{"x": 3, "y": [1,2,3]}');

SELECT json_build_object('a',1,'b',1.2,'c',true,'d',null,'e',json '{"x": 3, "y": [1,2,3]}');

SELECT json_build_object(
       'a', json_build_object('b',false,'c',99),
       'd', json_build_object('e',array[9,8,7]::int[],
           'f', (select row_to_json(r) from ( select relkind, oid::regclass as name from pg_class where relname = 'pg_class') r)));

-- empty objects/arrays
SELECT json_build_array();

SELECT json_build_object();

-- make sure keys are quoted
SELECT json_build_object(1,2);

-- keys must be scalar and not null
SELECT json_build_object(null,2);

SELECT json_build_object(r,2) FROM (SELECT 1 AS a, 2 AS b) r;

SELECT json_build_object(json '{"a":1,"b":2}', 3);

SELECT json_build_object('{1,2,3}'::int[], 3);

CREATE TEMP TABLE foo (serial_num int, name text, type text);
INSERT INTO foo VALUES (847001,'t15','GE1043');
INSERT INTO foo VALUES (847002,'t16','GE1043');
INSERT INTO foo VALUES (847003,'sub-alpha','GESS90');

SELECT json_build_object('turbines',json_object_agg(serial_num,json_build_object('name',name,'type',type)))
FROM foo;

SELECT json_object_agg(name, type) FROM foo;

INSERT INTO foo VALUES (999999, NULL, 'bar');
SELECT json_object_agg(name, type) FROM foo;

-- json_object

-- empty object, one dimension
SELECT json_object('{}');

-- empty object, two dimensions
SELECT json_object('{}', '{}');

-- one dimension
SELECT json_object('{a,1,b,2,3,NULL,"d e f","a b c"}');

-- same but with two dimensions
SELECT json_object('{{a,1},{b,2},{3,NULL},{"d e f","a b c"}}');

-- odd number error
SELECT json_object('{a,b,c}');

-- one column error
SELECT json_object('{{a},{b}}');

-- too many columns error
SELECT json_object('{{a,b,c},{b,c,d}}');

-- too many dimensions error
SELECT json_object('{{{a,b},{c,d}},{{b,c},{d,e}}}');

--two argument form of json_object

select json_object('{a,b,c,"d e f"}','{1,2,3,"a b c"}');

-- too many dimensions
SELECT json_object('{{a,1},{b,2},{3,NULL},{"d e f","a b c"}}', '{{a,1},{b,2},{3,NULL},{"d e f","a b c"}}');

-- mismatched dimensions

select json_object('{a,b,c,"d e f",g}','{1,2,3,"a b c"}');

select json_object('{a,b,c,"d e f"}','{1,2,3,"a b c",g}');

-- null key error

select json_object('{a,b,NULL,"d e f"}','{1,2,3,"a b c"}');

-- empty key is allowed

select json_object('{a,b,"","d e f"}','{1,2,3,"a b c"}');


-- json_to_record and json_to_recordset

select * from json_to_record('{"a":1,"b":"foo","c":"bar"}')
    as x(a int, b text, d text);

select * from json_to_recordset('[{"a":1,"b":"foo","d":false},{"a":2,"b":"bar","c":true}]')
    as x(a int, b text, c boolean);

select * from json_to_recordset('[{"a":1,"b":{"d":"foo"},"c":true},{"a":2,"c":false,"b":{"d":"bar"}}]')
    as x(a int, b json, c boolean);

select *, c is null as c_is_null
from json_to_record('{"a":1, "b":{"c":16, "d":2}, "x":8}'::json)
    as t(a int, b json, c text, x int);

select *, c is null as c_is_null
from json_to_recordset('[{"a":1, "b":{"c":16, "d":2}, "x":8}]'::json)
    as t(a int, b json, c text, x int);

-- json_strip_nulls

select json_strip_nulls(null);

select json_strip_nulls('1');

select json_strip_nulls('"a string"');

select json_strip_nulls('null');

select json_strip_nulls('[1,2,null,3,4]');

select json_strip_nulls('{"a":1,"b":null,"c":[2,null,3],"d":{"e":4,"f":null}}');

select json_strip_nulls('[1,{"a":1,"b":null,"c":2},3]');

-- an empty object is not null and should not be stripped
select json_strip_nulls('{"a": {"b": null, "c": null}, "d": {} }');

-- json to tsvector
select to_tsvector('{"a": "aaa bbb ddd ccc", "b": ["eee fff ggg"], "c": {"d": "hhh iii"}}'::json);

-- json to tsvector with config
select to_tsvector('simple', '{"a": "aaa bbb ddd ccc", "b": ["eee fff ggg"], "c": {"d": "hhh iii"}}'::json);

-- json to tsvector with stop words
select to_tsvector('{"a": "aaa in bbb ddd ccc", "b": ["the eee fff ggg"], "c": {"d": "hhh. iii"}}'::json);

-- ts_vector corner cases
select to_tsvector('""'::json);
select to_tsvector('{}'::json);
select to_tsvector('[]'::json);
select to_tsvector('null'::json);

-- ts_headline for json
select ts_headline('{"a": "aaa bbb", "b": {"c": "ccc ddd fff", "c1": "ccc1 ddd1"}, "d": ["ggg hhh", "iii jjj"]}'::json, tsquery('bbb & ddd & hhh'));
select ts_headline('english', '{"a": "aaa bbb", "b": {"c": "ccc ddd fff"}, "d": ["ggg hhh", "iii jjj"]}'::json, tsquery('bbb & ddd & hhh'));
select ts_headline('{"a": "aaa bbb", "b": {"c": "ccc ddd fff", "c1": "ccc1 ddd1"}, "d": ["ggg hhh", "iii jjj"]}'::json, tsquery('bbb & ddd & hhh'), 'StartSel = <, StopSel = >');
select ts_headline('english', '{"a": "aaa bbb", "b": {"c": "ccc ddd fff", "c1": "ccc1 ddd1"}, "d": ["ggg hhh", "iii jjj"]}'::json, tsquery('bbb & ddd & hhh'), 'StartSel = <, StopSel = >');

-- corner cases for ts_headline with json
select ts_headline('null'::json, tsquery('aaa & bbb'));
select ts_headline('{}'::json, tsquery('aaa & bbb'));
select ts_headline('[]'::json, tsquery('aaa & bbb'));
