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
		public int64 remoteID { get; private set; }
		public string display_name { get; set; }
		public string mimetype { get; private set; }
		
		private Gee.Map<string, SyncedFileTag> tag_list;
		private Gee.List<SyncedFileVersion> version_list;
		private Database database;
		public static SyncedFileCache cache;

		internal SyncedFile(Database database,
		                    int64 remoteID,
		                    string name,
		                    string mimetype) throws DatabaseError
		{
			this.remoteID = remoteID;
			this.display_name = name;
			this.mimetype = mimetype;			
			this.database = database;
			this.tag_list = new Gee.HashMap<string, SyncedFileTag>();
			this.version_list = new Gee.ArrayList<SyncedFileVersion>();
			
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
			cache.add(this);
		}

		internal SyncedFile.create(Database database, string name, string mimetype)
		{
			this.display_name = name;
			this.mimetype = mimetype;			
			this.database = database;
			this.tag_list = new Gee.HashMap<string, SyncedFileTag>();
			this.version_list = new Gee.ArrayList<SyncedFileVersion>();
			
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
			cache.add(this);
		}
	
		private SyncedFile.from_result(Database database, Sqlite.Statement stmt)
		{
			this.database = database;
			ID = stmt.column_int64(COLUMN_ID);
			remoteID = stmt.column_int64(COLUMN_REMOTE_ID);
			display_name = stmt.column_text(COLUMN_DISPLAY_NAME);
			mimetype = stmt.column_text(COLUMN_MIMETYPE);
		
			this.tag_list = SyncedFileTag.find_tags_for_file(this, database);
			this.version_list = SyncedFileVersion.find_versions_for_file(this, database);
			cache.add(this);
		}

		public static SyncedFile? from_ID(Database database, int64 ID)
		{
			if (cache.has(ID))
			{
				return cache.get(ID);
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

		public static SyncedFile? from_remote(Database database, int64 remoteID)
		{
			/**
			 * Technically we could have a remote to ID mapping,
			 * and make use of the ID to do a cache lookup.
			 * We don't do this because it is too hard to keep the remote mapping
			 * in a correct state (and will use memory).
			 * Also we don't cache for doing the one-query less gain,
			 * but primarly for the max-one-instance per row assertion.
			*/
		
			Sqlite.Statement find_stmt = database.prepare("SELECT * FROM SyncedFile
			               WHERE remoteID=@remoteID");
			find_stmt.bind_int64(find_stmt.bind_parameter_index("@remoteID"), remoteID);
			int rc = find_stmt.step();
			if (rc == Sqlite.ROW)
			{
				int64 ID = find_stmt.column_int64(COLUMN_ID);
				if (cache.has(ID))
				{
					return cache.get(ID);
				}
			
				return new SyncedFile.from_result(database, find_stmt);
			}
			else
			{
				return null;
			}
		}
		
		public static Gee.List<SyncedFile> unsynced(Database database)
		{
			Sqlite.Statement find = database.prepare("SELECT * FROM SyncedFile WHERE remoteID IS NULL");
			
			Gee.List<SyncedFile> list = new Gee.ArrayList<SyncedFile>();
			
			while (find.step() == Sqlite.ROW)
			{
				int64 ID = find.column_int64(COLUMN_ID);
				if (cache.has(ID))
				{
					list.add(cache.get(ID));
				}
				else
				{
					list.add(new SyncedFile.from_result(database, find));
				}
			}
			return list;
		}
		
		public LocalFile? get_local_file()
		{
			return LocalFile.from_file_id(ID, database);
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
	
		public Gee.List<SyncedFileVersion> versions()
		{
			return version_list.read_only_view;
		}
		
		public void add_version(SyncedFileVersion version)
		{
			version_list.add(version);
			new_version(version, true);
		}
		
		public void remove_version(SyncedFileVersion version)
		{
			version_list.remove_at(version_list.index_of(version));
			removed_version(version);
		}
		
		public bool has_remote()
		{
			return remoteID != 0;
		}
		
		internal void set_remote(int64 remoteID)
		{
			this.remoteID = remoteID;
			
			Sqlite.Statement statement = database.prepare("UPDATE SyncedFile
			    SET remoteID = @remoteID
			    WHERE ID = @ID");
			statement.bind_int64(statement.bind_parameter_index("@remoteID"), remoteID);
			statement.bind_int64(statement.bind_parameter_index("@ID"), ID);
			statement.step();
		}
		
		internal bool remote_new_version(SyncedFileVersion sf_version)
		{
			if (!version_list.is_empty)
			{
				if (!version_list.last().is_remote())
				{
					version_list.insert(version_list.size - 1, sf_version);
					new_version(sf_version, false);
					return false;
				}
			}
			version_list.add(sf_version);
			new_version(sf_version, false);
			return true;
		}
	
		private void internal_tag(string tag, bool synced)
		{
			SyncedFileTag.Status status = synced ? SyncedFileTag.Status.SYNCED :
			                                       SyncedFileTag.Status.NEW;
			
			if (tag in tag_list.keys)
			{
				if (tag_list[tag].status == SyncedFileTag.Status.NEW)
				{
					// Do not resend tagged signal.
					tag_list[tag].status = status;
					return;
				}
				tag_list[tag].status = status;
			}
			else
			{
				SyncedFileTag sf_tag = new SyncedFileTag(tag, this, status, database);
				tag_list.set(tag, sf_tag);
			}
			tagged(tag, !synced);
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
				
				if (sf_tag.status == SyncedFileTag.Status.DELETED)
				{
					// Do not resend untagged signal.
					return;
				}
			}
			else
			{
				if (sf_tag.status == SyncedFileTag.Status.DELETED)
				{
					// Do not resend untagged signal.
					return;
				}
				sf_tag.status = SyncedFileTag.Status.DELETED;
			}
			
			untagged(tag, !synced);
		}
		
		internal void tag_from_remote(string tag)
		{
			internal_tag(tag, true);
		}
		
		internal void untag_from_remote(string tag)
		{
			internal_untag(tag, true);
		}
	
		public signal void tagged(string tag, bool local);
		public signal void untagged(string tag, bool local);
		
		public signal void new_version(SyncedFileVersion new_version, bool local);	
		public signal void removed_version(SyncedFileVersion old_version);
	}
}
