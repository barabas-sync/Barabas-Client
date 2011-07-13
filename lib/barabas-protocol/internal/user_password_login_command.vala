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
	class UserPasswordLoginCommand : ICommand
	{
		public override string command_type { get { return "login"; } }
		
		private UserPasswordAuthentication authentication;
		
		public UserPasswordLoginCommand (UserPasswordAuthentication authentication)
		{
			this.authentication = authentication;
		}

		public override Json.Generator? execute ()
		{
			Json.Generator gen;
			var login = json_message(out gen);

			login.set_string_member("request", "login");
			login.set_string_member("login-module", "user-password");
			
			Json.Object module_info = new Json.Object();
			module_info.set_string_member("username", authentication.username);
			module_info.set_string_member("password", authentication.password);
			login.set_object_member("module-info", module_info);
		
			return gen;
		}
	
		public override void response (Json.Object response)
		{
			int64 code = response.get_int_member("code");
			if (code == 200)
			{
				authenticated();
			}
			else
			{
				failure(response.get_string_member("msg"));
			}
		}
		
		public signal void authenticated();
		public signal void failure(string reason);
	}
}
