/**
    This file is part of Barabas DBus Library.

	Copyright (C) 2011 Nathan Samson
 
    Barabas DBus Library is free software: you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Barabas DBus Library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General Public License
    along with Barabas DBus Library.  If not, see <http://www.gnu.org/licenses/>.
*/

namespace Barabas.Client
{
	public class SyncedFile : Object
	{
		private enum TagStatus
		{
			NEW = 0,
			SYNCED = 1,
			DELETED = 2
		}

		public int64 ID { get; private set; }
		public string display_name { get; set; }
		public string mimetype { get; private set; }
		
		private Gee.Map<string, TagStatus> tag_list;
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
		                    int64 ID,
		                    string name,
		                    string mimetype) throws DatabaseError
		{
			assert_has_cache();
			this.ID = ID;
			this.display_name = name;
			this.mimetype = mimetype;			
			this.database = database;
			this.tag_list = new Gee.HashMap<string, TagStatus>();
			
			Sqlite.Statement stmt = database.prepare("INSERT INTO SyncedFile
			                 (ID, displayName, mimetype)
			           VALUES(@ID, @displayName, @mimetype);");
			stmt.bind_int64(stmt.bind_parameter_index("@ID"), ID);
			stmt.bind_text(stmt.bind_parameter_index("@displayName"), display_name);
			stmt.bind_text(stmt.bind_parameter_index("@mimetype"), mimetype);
			if (stmt.step() != Sqlite.DONE)
			{
				throw new DatabaseError.INSERT_ERROR("");
			}
		}
	
		private static SyncedFile.from_result(Database database, Sqlite.Statement stmt)
		{
			this.database = database;
			tag_list = new Gee.HashMap<string, TagStatus>();
			ID = stmt.column_int64(0);
			display_name = stmt.column_text(1);
			mimetype = stmt.column_text(2);
		
			Sqlite.Statement tag_stmt = database.prepare("SELECT tag, status FROM SyncedFileTag WHERE fileID=@fileID;");
			tag_stmt.bind_int64(tag_stmt.bind_parameter_index("@fileID"), ID);
		
			int tag_rc = tag_stmt.step();
			while (tag_rc == Sqlite.ROW)
			{
				tag_list.set(tag_stmt.column_text(0), (TagStatus)tag_stmt.column_int(1));
				tag_rc = tag_stmt.step();
			}
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
			if (tag in tag_list.keys && tag_list[tag] != TagStatus.DELETED)
			{
				return false;
			}
			else
			{
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
			if (tag_list.size == 0)
			{
				return {""}; // Hack, returning an empty array crashes for some reason...
			}
			string[] tag_array = {};
			foreach (var entry in tag_list.entries)
			{
				if (entry.value != TagStatus.DELETED)
				{
					tag_array += entry.key;
				}
			}
			if (tag_array.length == 0)
			{
				return {""}; // Hack, returning an empty array crashes for some reason...
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
			Sqlite.Statement stmt = database.prepare("INSERT INTO SyncedFileTag (fileID, tag, status) VALUES(@fileID, @tag, @status);");
			stmt.bind_int64(stmt.bind_parameter_index("@fileID"), ID);
			stmt.bind_text(stmt.bind_parameter_index("@tag"), tag);
			TagStatus status = synced ? TagStatus.NEW : TagStatus.SYNCED;
			stmt.bind_int(stmt.bind_parameter_index("@status"), status);
			stmt.step();
			tag_list.set(tag, status);
			tagged(tag);
		}
		
		private void internal_untag(string tag, bool synced)
		{
			Sqlite.Statement stmt = null;
			
			if (!synced)
			{
				TagStatus current_status = tag_list[tag];
				switch (current_status) {
					case TagStatus.NEW:
						tag_list.unset(tag);
						stmt = database.prepare("DELETE FROM SyncedFileTag WHERE fileID=@fileID AND tag=@tag");
						break;
					case TagStatus.SYNCED:
						tag_list.set(tag, TagStatus.DELETED);
						stmt = database.prepare("UPDATE SyncedFileTag SET status=@status WHERE fileID=@fileID AND tag=@tag");
						stmt.bind_int(stmt.bind_parameter_index("@status"), TagStatus.DELETED);
						break;
					case TagStatus.DELETED:
						// Nothing has to happen
						break;
					default:
						// This never happens in principle...
						break;
				}
			}
			else
			{
				stmt = database.prepare("DELETE FROM SyncedFileTag
				                         WHERE fileID=@fileID AND tag=@tag;");
			
				tag_list.unset(tag);
			}
			
			if (stmt != null)
			{
				stmt.bind_int64(stmt.bind_parameter_index("@fileID"), ID);
				stmt.bind_text(stmt.bind_parameter_index("@tag"), tag);
				stmt.step();
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
	
		public void remove()
		{
			/*var delete_stmt = database.prepare("DELETE FROM SyncedFile WHERE ID=@ID");
			delete_stmt.bind_int(delete_stmt.bind_parameter_index("@ID"), id);
			delete_stmt.step();*/
		}
	
		/*internal void add_version(SyncedFileVersion version)
		{
			//version.save(database);
			version_added(version.ID);
		}*/
	
		public signal void tagged(string tag);
		public signal void untagged(string tag);		
	}
}
