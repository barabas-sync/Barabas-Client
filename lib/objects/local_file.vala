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
	public class LocalFile : Object
	{
		private int64 ID;
		public int64 syncedID;
		public string uri { get; private set; }
		private string parent_uri;
		public string display_name { get; private set; }
		private string mimetype;
		
		private Database database;
		
		private LocalFile(string uri)
		{
			GLib.File file = GLib.File.new_for_uri(uri);
			this.uri = uri;
			this.parent_uri = file.get_parent().get_uri();
			GLib.FileInfo file_info = file.query_info(
			               GLib.FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME + "," +
			               GLib.FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE,
			           GLib.FileQueryInfoFlags.NONE,
			           null);
			this.display_name = file_info.get_display_name();
			this.mimetype = file_info.get_content_type();
			
			this.database = null;
		}
		
		private LocalFile.from_statement(Sqlite.Statement stmt, Database database)
		{
			this.database = database;
			
			this.ID = stmt.column_int(0);
			this.syncedID = stmt.column_int(1);
			this.uri = stmt.column_text(2);
			this.parent_uri = stmt.column_text(3);
			this.display_name = stmt.column_text(4);
		}
		
		public SyncedFile? sync(Database database)
		{
			if (is_synced())
			{
				return null;
			}
		
			// Let's create a sync file for this.
			string mime_type = "unknown";
			SyncedFile synced_file = new SyncedFile.create(database, display_name, mime_type);
			
			Sqlite.Statement insert_stmt = database.prepare("INSERT INTO 
			         LocalFile (fileID, uri, parentURI, displayName)
			         VALUES (@fileID, @uri, @parentURI, @displayName);");
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@fileID"), synced_file.ID);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@uri"), uri);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@parentURI"), parent_uri);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@displayName"), display_name);
			insert_stmt.step();
			this.ID = database.last_insert_row_id();
			
			this.database = database;
			synced(synced_file);
			return synced_file;
		}
		
		public bool is_synced()
		{
			return database != null;
		}
		
		public static LocalFile from_uri(string uri, Database database)
		{
			Sqlite.Statement select = database.prepare("SELECT * FROM LocalFile
			    WHERE uri = @uri;");
			select.bind_text(select.bind_parameter_index("@uri"), uri);
			int rc = select.step();
			
			LocalFile local_file = null;
			if (rc == Sqlite.ROW)
			{
				local_file = new LocalFile.from_statement(select, database);
			}
			else
			{
				local_file = new LocalFile(uri);
			}
			
			return local_file;
		}
		
		public signal void synced(SyncedFile synced_file);
	}
}
