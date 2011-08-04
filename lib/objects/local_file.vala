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
		public string parent_uri { get; private set; }
		public string display_name { get; private set; }
		private string mimetype;
		
		private Database database;
		public static LocalFileCache cache;
		
		private LocalFile(string uri) throws GLib.Error
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
			cache.add(this);
		}
		
		public LocalFile.local_copy(string uri,
		                            SyncedFile synced_file,
		                            Database database) throws GLib.Error
		{
			this.database = database;
			this.syncedID = synced_file.ID;
			this.uri = uri;
			
			GLib.File file = GLib.File.new_for_uri(uri);
			this.parent_uri = file.get_parent().get_uri();
			GLib.FileInfo file_info = file.query_info(
			           GLib.FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME,
			           GLib.FileQueryInfoFlags.NONE,
			           null);
			this.display_name = file_info.get_display_name();
			this.mimetype = synced_file.mimetype;
			
			insert();
			cache.add(this);
		}
		
		private LocalFile.from_statement(Sqlite.Statement stmt, Database database)
		{
			this.database = database;
			
			this.ID = stmt.column_int(0);
			this.syncedID = stmt.column_int(1);
			this.uri = stmt.column_text(2);
			this.parent_uri = stmt.column_text(3);
			this.display_name = stmt.column_text(4);
			
			cache.add(this);
		}
		
		public SyncedFile? sync(Database database)
		{
			if (is_synced())
			{
				return null;
			}
		
			// Let's create a sync file for this.
			SyncedFile synced_file = new SyncedFile.create(database, display_name, mimetype);
			syncedID = synced_file.ID;
			this.database = database;
			
			insert();
			
			synced(synced_file);
			return synced_file;
		}
		
		public bool is_synced()
		{
			return database != null;
		}
		
		public static LocalFile? from_file_id(int64 ID, Database database)
		{
			Sqlite.Statement select = database.prepare("SELECT * FROM LocalFile
			    WHERE fileID = @fileID;");
			select.bind_int64(select.bind_parameter_index("@fileID"), ID);
			
			if (select.step() == Sqlite.ROW)
			{
				string uri = select.column_text(2);
				if (cache.has(uri))
				{
					return cache.get(uri);
				}
			
				return new LocalFile.from_statement(select, database);
			}
			else
			{
				return null;
			}
		}
		
		public static LocalFile? from_uri(string uri,
		                                  Database database,
		                                  bool create = true) throws GLib.Error
		{
			if (cache.has(uri))
			{
				return cache.get(uri);
			}
		
			Sqlite.Statement select = database.prepare("SELECT * FROM LocalFile
			    WHERE uri = @uri;");
			select.bind_text(select.bind_parameter_index("@uri"), uri);
			int rc = select.step();
			
			LocalFile local_file = null;
			if (rc == Sqlite.ROW)
			{
				GLib.log("database", LogLevelFlags.LEVEL_INFO, "Found %s", uri);
				local_file = new LocalFile.from_statement(select, database);
			}
			else if (create)
			{
				GLib.log("database", LogLevelFlags.LEVEL_INFO, "Creating %s", uri);
				local_file = new LocalFile(uri);
			}
			else
			{
				return null;
			}
			
			return local_file;
		}
		
		public void rename(string display_name, string uri)
		{
			this.display_name = display_name;
			cache.unset(this.uri);
			this.uri = uri;
			cache.add(this);
			
			if (database != null)
			{
				Sqlite.Statement update_stmt = database.prepare("
				    UPDATE LocalFile
				           SET displayName=@displayName, uri=@uri
				           WHERE ID=@ID");
				update_stmt.bind_int64(update_stmt.bind_parameter_index("@ID"), ID);
				update_stmt.bind_text(update_stmt.bind_parameter_index("@uri"), uri);
				update_stmt.bind_text(update_stmt.bind_parameter_index("@displayName"), display_name);
				update_stmt.step();
			}
		}
		
		public void remove()
		{
			if (database != null)
			{
				Sqlite.Statement delete_stmt = database.prepare("
				    DELETE FROM LocalFile WHERE ID=@ID");
				delete_stmt.bind_int64(delete_stmt.bind_parameter_index("@ID"), ID);
				delete_stmt.step();
			}
		}
		
		public signal void synced(SyncedFile synced_file);
		public signal void initiate_upload(SyncedFile synced_file,
		                                   SyncedFileVersion synced_file_version);
		
		private void insert()
		{
			Sqlite.Statement insert_stmt = database.prepare("INSERT INTO 
			         LocalFile (fileID, uri, parentURI, displayName)
			         VALUES (@fileID, @uri, @parentURI, @displayName);");
			insert_stmt.bind_int64(insert_stmt.bind_parameter_index("@fileID"), syncedID);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@uri"), uri);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@parentURI"), parent_uri);
			insert_stmt.bind_text(insert_stmt.bind_parameter_index("@displayName"), display_name);
			insert_stmt.step();
			
			this.ID = database.last_insert_row_id();
		}
	}
}
