/** Functions for throwing exceptions on WinAPI errors.

Copyright: Denis Shelomovskij 2013

License: $(HTTP boost.org/LICENSE_1_0.txt, Boost License 1.0).

Authors: Denis Shelomovskij
*/
module unstd.windows.exception;


import core.sys.windows.windows;

import std.traits;

version(unittest)
{
	import std.algorithm;
	import std.exception;
}


/**
Exception thrown on WinAPI errors.
*/
class WinAPIException: Exception
{
	this(string functionName, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @safe pure nothrow
	{ super("WinAPI function '" ~ functionName ~ "' failed.", file, line, next); }
}

/**
Convinient template to call WinAPI function and throw $(MREF WinAPIException)
on error.
*/
template enforceWinAPI(alias func)
if(functionLinkage!func == "Windows")
{
	auto enforceWinAPI(ParameterTypeTuple!func args, string file = __FILE__, size_t line = __LINE__)
	{
		if(auto res = func(args))
			return res;
		throw new WinAPIException(__traits(identifier, func), file, line);
	}
}

///
unittest
{
	HANDLE processHeap = enforceWinAPI!GetProcessHeap();
	assert(processHeap); // Will always pass.
}

unittest
{
	assert(enforceWinAPI!GetProcessHeap() == GetProcessHeap());
	assert(collectExceptionMsg!WinAPIException(enforceWinAPI!CloseHandle(null)).canFind("CloseHandle"));
}

version(unittest)
extern(Windows) nothrow extern HANDLE GetProcessHeap();
