#!/usr/bin/env lua

local lxsh = require"lxsh"

-- Possible bugs
-- The first line is always printed/ignored and assumed to be #!
-- syntactic additions of lua5.4 ie <>
-- probably wont be recognized by lxsh and here as well

local subCommand = {}

local function PrintUsageAndExit(exit)
print[[
    luafmt subcommand file

 Subcommands:
	codeline -- line of code, no comments! (no whitespace!)
	cozyline -- like codeline, but keeps your structure, (few whitespace)
	spaceyline -- line of code, but adds spaces for a slight bit of readability
	look -- spits out what the lxsh lexer sees


	Examples:	print( "hello world"      ..      "."    )

		Cozyline: print( "hello world" .. "." )
		Codeline:	print("hello world".. ".")
		spaceyline:  print ( "hello world" .. "." )
]]
	os.exit(exit or 0)
end

-- checks for hashbang, prints it, and returns continuation or beginning of file
local function HashBangCheck(H)
 local x = H:read"l":match"^#!.+"
 if x then print(x) else H:seek"set" end
end

local function PrintError(kind,text)
 io.stderr:write(
  "\n\n>>>>>", kind, "\n\n"
  ,"\n\n>>>>>", text, "\n\n"
 )
end


-- prints everything
function subCommand.Look(H)
-- for kind, text, lnum, cnum in lxsh.lexers.lua.gmatch(f:read"a") do
 for kind, text in lxsh.lexers.lua.gmatch(H:read"a") do
	print(kind, text)
 end
 return 0
end

----------------------------------------------------( Cozyline
-- A single line of code, but with spaces, keeps most of the structure
do
	local kindSwallow = {
		identifier = true
		,operator = true
		,string = true
		,number = true
		,constant = true
		,keyword = true
	}
	function subCommand.cozyline(H)
	 local t,i = {""}, 2
	 for kind, text in lxsh.lexers.lua.gmatch(H:read"a") do
		if kindSwallow[kind] then
			t[i],i = text,i+1
		elseif kind=="whitespace" and t[i-1]:match"%S+$" then
			t[i],i = " ",i+1 -- whitespace is aggregated, so only add " "
--		elseif kind=="whitespace" or kind=="comment" then -- NOOP | ignore
		elseif kind~="whitespace" and kind~="comment" then
			io.stderr:write("\n\n>>>>>", kind, text,"\n\n")
		end
	 end
	 print( table.concat(t) )
	 return 0
	end
end


do ----------------------------------------------------( Spaceyline
	-- A single line of code, but with spaces
	-- a slightly more readable version of cozyline
	local appendToken = {
		identifier = true
		,operator = true
		,string = true
		,number = true
		,constant = true
		,keyword = true
	}
	function subCommand.spaceyline(H)
	 local t,i = {""}, 2
	 for kind, text in lxsh.lexers.lua.gmatch(H:read"a") do
		if -- appends to last token
				kind=="operator" and text=="."
			or
				kind=="operator" and text==":"
			or
				kind=="identifier" and t[i-1]~="" and t[i-1]:match"[:.]$"
		then -- append to last identifier
			t[i-1] = t[i-1] .. text
		elseif appendToken[kind] then
			t[i], i = text, i+1
--		elseif kind=="whitespace" or kind=="comment" then -- ignore
		elseif kind~="whitespace" and kind~="comment" then
			io.stderr:write("\n\n>>>>>", kind, text,"\n\n")
		end
	 end
	 print( table.concat(t, " ") )
	 return 0
	end
end ----------------------------------------------------) Cozyline

do ----------------------------------------------------( Codeline
	local appendIf = {
		identifier = true
		,operator = true
		,string = true
		,number = true
		,constant = true
		,keyword = true
	}
	-- NO WHITESPACE
	function subCommand.CodeLine(H)
	 local t,x,i = {""}, {"string"}, 2
	 for kind, text in lxsh.lexers.lua.gmatch(H:read"a") do
		if -- replacer
				-- operators dont need whitespace (sorta)
				kind=="operator" and t[i-1]==" "
				and text:match"^%p+$" -- not a boolean operator

			 or
				kind=="operator" and t[i-1]==" "
				-- boolean operators are concatenable (only with preceding numbers)
				and t[i-2] and x[i-2]=="number"
				and t[i-2]:match"%d$" -- number does end as a digit -- REMOVE
				and text:match"^%X" -- boolean operator cannot be confused with hex

			 or -- a number preceded by an operator doesn't need whitespace (sorta)
				kind=="number" and t[i-1]==" "
				and t[i-2] and t[i-2]:match"^%A+$"

			 or
				-- a number can follow an identifier (sorta) but
				-- an identifier cant follow a number
				-- if the current text/identifier doesn't begin with hex
				-- an identifier can precede a number
				kind=="identifier" and t[i-1]==" " and t[i-2]
					and text:match"^%X"
					and x[i-2]=="number"
				--		and t[i-2]:match"%d$"
			then
				t[i-1],x[i-1] = text, kind

			elseif appendIf[kind]
				-- identifier, operator, string, number, constant, keyword
				then
					t[i],x[i], i = text, kind, i+1 -- append

			elseif kind=="whitespace"
					and t[i-1]:match"%S+$" -- dont add additional whitespace
					and t[i-1]:match"[^(){}=\034',%]]$" --
				then
					-- whitespace is aggregated, so only add " "
					t[i], x[i], i = " ",kind, i+1
--			elseif kind=="whitespace" or kind=="comment" then -- ignore
			elseif kind~="whitespace" and kind~="comment" then -- ignore
				PrintError(kind,text)
		end -- if
	 end -- for
	 print( table.concat(t) )
	 return 0
	end -- function
end ------------------------------------------------------) Codeline

do
	for k,v in pairs(subCommand) do subCommand[k:lower()] = v end
	local subcommand = arg[1] and arg[1]:lower() or PrintUsageAndExit(0)
	local fileS = arg[2] or PrintUsageAndExit(0)
	local H = io.open(fileS)
	HashBangCheck(H)
	local exit = subCommand[subcommand](H) or 3
	H:close()
	os.exit(exit)
end
