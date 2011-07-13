/**
    This file is part of Barabas Client Library.

	Copyright (C) 2011 Nathan Samson
 
    Barabas Client Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas Client Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Barabas Client Library.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.Client
{
	class HandshakeCommand : ICommand
	{
		public string[] authentication_methods;
		public override string command_type { get { return "handshake"; } }

		public HandshakeCommand (string[] authentication_methods)
		{
			this.authentication_methods = authentication_methods;
		}

		public override Json.Generator? execute ()
		{
			Json.Generator gen;
			var handshake = json_message(out gen);

			handshake.set_string_member("request", command_type);
			handshake.set_string_member("protocol", "fst");
			handshake.set_int_member("version", 1);
			
			Json.Array login_modules = new Json.Array();
			foreach (string authentication_method in authentication_methods)
			{
				login_modules.add_string_element(authentication_method);
			}
			handshake.set_array_member("login-modules", login_modules);
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{
			int64 code = response.get_int_member("code");
			if (code == ReturnCode.SUCCESS)
			{
				Json.Array login_modules = response.get_array_member("login-modules");
				string[] authentication_methods = {};
				login_modules.foreach_element((array, index, node) => {
					authentication_methods += login_modules.get_string_element(index);
				});
				success(authentication_methods);
			}
			else
			{
				// TODO: look at some well known codes, and return translated strings
				failure(response.get_string_member("msg"));
			}
		}
		
		public signal void success(string[] authentication_methods);
		public signal void failure(string message);
	}
}
