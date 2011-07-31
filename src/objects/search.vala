/**
    This file is part of Barabas DBUS Client.

	Copyright (C) 2011 Nathan Samson
 
    Barabas DBUS Client is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas DBUS Client is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Barabas DBUS Client.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.DBus.Server
{
	[DBus (name = "be.ac.ua.comp.Barabas.Search")]
	public class Search : AResource
	{
		private Client.Database database;
		
		private string search_query;
		private Gee.Set<int64?> results;

		public Search(string search_query, Client.Database database)
		{
			this.database = database;
			this.search_query = search_query;
			this.results = new Gee.HashSet<int64?>();
		}
		
		public int64[] get_results()
		{
			return results.to_array();
		}
		
		internal void start_search()
		{
			string[] tags = search_query.split(" ");
			string tag_list = "@tag_0";
			for(int tag_no = 1; tag_no < tags.length; tag_no++)
			{
				tag_list += ", @tag_" + tag_no.to_string();
			}

			Sqlite.Statement stmt = database.prepare("SELECT * FROM SyncedFile WHERE ID IN
				       (SELECT fileID FROM SyncedFileTag WHERE tag IN ("+tag_list+") 
				                                   GROUP BY fileID
				                                   HAVING COUNT(*) >= @number_of_tags)");
			stmt.bind_int(stmt.bind_parameter_index("@number_of_tags"), tags.length);
			
			for(int tag_no = 0; tag_no < tags.length; tag_no++)
			{
				stdout.printf("T: %s\n", tags[tag_no]);
				stmt.bind_text(stmt.bind_parameter_index("@tag_" + tag_no.to_string()), tags[tag_no]);
			}
			
			stdout.printf("EXEC: %s\n", tag_list);
			
			int rc = stmt.step();
			stdout.printf("EXEC: %s\n", stmt.sql());
		
			while (rc == Sqlite.ROW)
			{
				int64 file_id = stmt.column_int64(0);
				results.add(file_id);
				add_result(file_id);
				rc = stmt.step();
			}
		}
		
		internal signal void add_result(int64 file_id);
		
		protected override void do_register(string path, DBusConnection connection)
		{
			connection.register_object(path, this);
		}
	}
}
