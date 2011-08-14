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
	public abstract class ICommand
	{
		public abstract Json.Generator? execute();
		public abstract void response(Json.Object response);
		public abstract string command_type { get; }
	
		protected Json.Object json_message(out Json.Generator gen)
		{
			gen = new Json.Generator();
			var root = new Json.Node(Json.NodeType.OBJECT);
			var object = new Json.Object();
			root.set_object(object);
			gen.set_root(root);
			return object;
		}
		
		protected enum ReturnCode
		{
			SUCCESS = 200
		}
		
		protected string to_barabas_date(DateTime datetime)
		{
			return datetime.format("%Y-%m-%dT%H:%M:%S%z");
		}
		
		protected DateTime from_barabas_date(string date)
		{
			string datetimepart = date.substring(0, 19);
			int year = date.substring(0, 4).to_int();
			int month = date.substring(5, 2).to_int();
			int day = date.substring(8, 2).to_int();
			int hours = date.substring(11, 2).to_int();
			int minutes = date.substring(14, 2).to_int();
			int seconds = date.substring(17, 2).to_int();
			TimeZone timezone = new TimeZone(date.substring(19));
	
			return new DateTime(timezone,
					            year,
					            month,
					            day,
					            hours,
					            minutes,
					            seconds);
		}
	}
}
