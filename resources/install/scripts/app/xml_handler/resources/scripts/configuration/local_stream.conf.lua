
--connect to the database
	require "resources.functions.database_handle";
	dbh = database_handle('system');

--exits the script if we didn't connect properly
	assert(dbh:connected());

--start the xml array
	local xml = {}
	table.insert(xml, [[<?xml version="1.0" encoding="UTF-8" standalone="no"?>]]);
	table.insert(xml, [[<document type="freeswitch/xml">]]);
	table.insert(xml, [[	<section name="configuration">]]);
	table.insert(xml, [[		<configuration name="local_stream.conf" description="stream files from local dir">]]);

--set the default music on hold
	table.insert(xml, [[		<!-- fallback to default if requested moh class isn't found -->]]);
	table.insert(xml, [[		<directory name="default" path="]]..sounds_dir..[[/music/default/8000">]]);
	table.insert(xml, [[			<param name="rate" value="8000"/>]]);
	table.insert(xml, [[			<param name="shuffle" value="true"/>]]);
	table.insert(xml, [[			<param name="channels" value="1"/>]]);
	table.insert(xml, [[			<param name="interval" value="20"/>]]);
	table.insert(xml, [[			<param name="timer-name" value="soft"/>]]);
	table.insert(xml, [[			<!-- list of short files to break in with every so often -->]]);
	table.insert(xml, [[			<!--<param name="chime-list" value="file1.wav,file2.wav"/>-->]]);
	table.insert(xml, [[			<!-- frequency of break-in (seconds)-->]]);
	table.insert(xml, [[			<!--<param name="chime-freq" value="30"/>-->]]);
	table.insert(xml, [[			<!-- limit to how many seconds the file will play -->]]);
	table.insert(xml, [[			<!--<param name="chime-max" value="500"/>-->]]);
	table.insert(xml, [[		</directory>]]);

--run the query
	sql = "select * from v_music_on_hold ";
	sql = sql .. "order by music_on_hold_name asc ";
	if (debug["sql"]) then
		freeswitch.consoleLog("notice", "[xml_handler] SQL: " .. sql .. "\n");
	end
	x = 0;
	dbh:query(sql, function(row)

		--replace the variable with the path to the sounds directory
		music_on_hold_path = row.music_on_hold_path:gsub("$${sounds_dir}", sounds_dir);

		--add the full path to the chime list
		chime_list = row.music_on_hold_chime_list;
		if (chime_list ~= nil) then
			chime_array = explode(",", chime_list);
			chime_list = "";
			for k,v in pairs(chime_array) do
				f = explode("/", v);
				if (f[1] ~= nil and f[2] ~= nil and file_exists(sounds_dir.."/en/us/callie/"..f[1].."/8000/"..f[2])) then
					chime_list = chime_list .. sounds_dir.."/en/us/callie/"..v;
				else
					chime_list = chime_list .. v;
				end
			end
		end

		--set the default timer name to soft
		if (row.music_on_hold_timer_name == nil or row.music_on_hold_timer_name == '') then
			timer_name = "soft";
		else
			timer_name = row.music_on_hold_timer_name;
		end
		
		--build the xml ]]..row.music_on_hold_name..[["
		table.insert(xml, [[	<directory name="]]..row.music_on_hold_uuid..[[" stream_name="]]..row.music_on_hold_name..[[" path="]]..music_on_hold_path..[[">]]);
		table.insert(xml, [[			<param name="rate" value="]]..row.music_on_hold_rate..[["/>]]);
		table.insert(xml, [[			<param name="shuffle" value="]]..row.music_on_hold_shuffle..[["/>]]);
		table.insert(xml, [[			<param name="channels" value="1"/>]]);
		table.insert(xml, [[			<param name="interval" value="20"/>]]);
		table.insert(xml, [[			<param name="timer-name" value="]]..timer_name..[["/>]]);
		if (chime_list ~= nil) then
			table.insert(xml, [[			<param name="chime-list" value="]]..chime_list..[["/>]]);
		end
		if (row.music_on_hold_chime_freq ~= nil) then
			table.insert(xml, [[			<param name="chime-freq" value="]]..row.music_on_hold_chime_freq..[["/>]]);
		end
		if (row.music_on_hold_chime_max ~= nil) then
			table.insert(xml, [[			<param name="chime-max" value="]]..row.music_on_hold_chime_max..[["/>]]);
		end
		table.insert(xml, [[		</directory>]]);

	end)

--close the extension tag if it was left open
	table.insert(xml, [[		</configuration>]]);
	table.insert(xml, [[	</section>]]);
	table.insert(xml, [[</document>]]);
	XML_STRING = table.concat(xml, "\n");
	if (debug["xml_string"]) then
		freeswitch.consoleLog("notice", "[xml_handler] XML_STRING: " .. XML_STRING .. "\n");
	end

--close the database connection
	dbh:release();

--send the xml to the console
	if (debug["xml_string"]) then
		local file = assert(io.open(temp_dir .. "/local_stream.conf.xml", "w"));
		file:write(XML_STRING);
		file:close();
	end
