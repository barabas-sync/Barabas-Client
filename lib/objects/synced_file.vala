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
	public class SyncedFile : Object
	{
		private const int COLUMN_ID = 0;
		private const int COLUMN_REMOTE_ID = 1;
		private const int COLUMN_DISPLAY_NAME = 2;
		private const int COLUMN_MIMETYPE = 3;

		public int64 ID { get; private set; }
		private int64 remoteID { get; private set; }
		public string display_name { get; set; }
		public string mimetype { get; private set; }
		
		private Gee.Map<string, SyncedFileTag> tag_list;
		private Database database;
		private static Gee.Map<string, SyncedFile> cache = new Gee.HashMap<string, SyncedFile>();


		private static void assert_has_cache()
		{
			if (cache == null)
			{
				stderr.printf("Is their any reason we have private statics?");
			}
			cache = new Gee.HashMap<string, SyncedFile>();
		}

		internal SyncedFile(Database database,
		                    int64 remoteID,
		                    string name,
		                    string mimetype) throws DatabaseError
		{
			assert_has_cache();
			this.remoteID = remoteID;
			this.display_name = name;
			this.mimetype = mimetype;			
			this.database = database;
			this.tag_list = new Gee.HashMap<string, SyncedFileTag>();
			
			Sqlite.Statement stmt = database.prepare("INSERT INTO SyncedFile
			                 (remoteID, displayName, mimetype)
			           VALUES(@remoteID, @displayName, @mimetype);");
			stmt.bind_int64(stmt.bind_parameter_index("@remoteID"), remoteID);
			stmt.bind_text(stmt.bind_parameter_index("@displayName"), display_name);
			stmt.bind_text(stmt.bind_parameter_index("@mimetype"), mimetype);
			if (stmt.step() != Sqlite.DONE)
			{
				throw new DatabaseError.INSERT_ERROR("");
			}
			this.ID = database.last_insert_row_id();
		}
		
		internal SyncedFile.create(Database database, string name, string mimetype)
		{
			assert_has_cache();
			this.display_name = name;
			this.mimetype = mimetype;			
			this.database = database;
			this.tag_list = new Gee.HashMap<string, SyncedFileTag>();
			
			Sqlite.Statement stmt = database.prepare("INSERT INTO SyncedFile
			                 (displayName, mimetype)
			           VALUES(@displayName, @mimetype);");
			stmt.bind_text(stmt.bind_parameter_index("@displayName"), display_name);
			stmt.bind_text(stmt.bind_parameter_index("@mimetype"), mimetype);
			if (stmt.step() != Sqlite.DONE)
			{
				throw new DatabaseError.INSERT_ERROR("");
			}
			this.ID = database.last_insert_row_id();
		}
	
		private static SyncedFile.from_result(Database database, Sqlite.Statement stmt)
		{
			this.database = database;
			stdout.printf("Created tag list, stop bitching...\n");
			ID = stmt.column_int64(COLUMN_ID);
			remoteID = stmt.column_int64(COLUMN_REMOTE_ID);
			display_name = stmt.column_text(COLUMN_DISPLAY_NAME);
			mimetype = stmt.column_text(COLUMN_MIMETYPE);
		
			this.tag_list = SyncedFileTag.find_tags_for_file(this, database);
		}

		public static SyncedFile? from_remote(Database database, int64 ID)
		{
			assert_has_cache();
			string key = ID.to_string();
			if (SyncedFile.cache.has_key(key))
			{
				return cache.get(key);
			}
			else
			{
				Sqlite.Statement find_stmt = database.prepare("SELECT * FROM SyncedFile
				               WHERE ID=@ID");
				find_stmt.bind_int64(find_stmt.bind_parameter_index("@ID"), ID);
				int rc = find_stmt.step();
				if (rc == Sqlite.ROW)
				{
					return new SyncedFile.from_result(database, find_stmt);
				}
				else
				{
					return null;
				}
			}
		}

		public bool tag(string tag)
		{
			if (tag in tag_list.keys && tag_list[tag].status != 
			                            SyncedFileTag.Status.DELETED)
			{
				return false;
			}
			else
			{
				stdout.printf("Internal tag start %s\n", tag);
				internal_tag(tag, false);
				return true;
			}
		}
	
		public void untag(string tag)
		{
			if (tag in tag_list.keys)
			{
				internal_untag(tag, false);
			}
		}
	
		public string[] tags()
		{
			string[] tag_array = {};
			foreach (SyncedFileTag tag in tag_list.values)
			{
				if (tag.status != SyncedFileTag.Status.DELETED)
				{
					tag_array += tag.tag;
				}
			}
			return tag_array;
		}
	
		public int[] versions()
		{
			//Sqlite.Statement find_stmt = database.prepare("SELECT ID FROM SyncedFileVersion WHERE fileRemoteID=@fileRemoteID;");
			//find_stmt.bind_int(find_stmt.bind_parameter_index("@fileRemoteID"), (int)remote_id);
			int[] vs = {};
			/*while (find_stmt.step() == Sqlite.ROW)
			{
				vs += find_stmt.column_int(0);
			}*/
			return vs;
		}
	
		private void internal_tag(string tag, bool synced)
		{
			SyncedFileTag.Status status = synced ? SyncedFileTag.Status.SYNCED :
			                                       SyncedFileTag.Status.NEW;
			
			if (tag in tag_list.keys)
			{
				tag_list[tag].status = status;
			}
			else
			{
				stdout.printf("CREATE NEW TAG %s\n", tag);
				SyncedFileTag sf_tag = new SyncedFileTag(tag, this, status, database);
				tag_list.set(tag, sf_tag);
			}
			tagged(tag);
		}
		
		private void internal_untag(string tag, bool synced)
		{
			if (!(tag in tag_list.keys))
			{
				return;
			}
			SyncedFileTag sf_tag = tag_list[tag];
			
			
			if (synced)
			{
				sf_tag.remove();
				tag_list.unset(tag);
			}
			else
			{
				sf_tag.status = SyncedFileTag.Status.DELETED;
			}
			
			untagged(tag);
		}
		
		internal void tag_from_remote(string tag)
		{
			// TODO: fix the situatation whree local tag is set to new
			internal_tag(tag, true);
		}
		
		internal void untag_from_remote(string tag)
		{
			internal_untag(tag, true);
		}
	
		public signal void tagged(string tag);
		public signal void untagged(string tag);		
	}
}
