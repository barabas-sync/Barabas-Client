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
	public class Database
	{
		private Sqlite.Database database;

		public Database() throws DatabaseError
		{
			string path = Path.build_filename(Environment.get_user_data_dir(), "barabas");
			string db_file = Path.build_filename(path, "barabas-0.1.12.sqlite");
			if (!FileUtils.test(path, GLib.FileTest.IS_DIR))
			{
				DirUtils.create_with_parents(path, 0770);
			}
			bool installed = FileUtils.test(db_file, GLib.FileTest.EXISTS);
		
			int rc = Sqlite.Database.open(db_file, out database);
		
			if (! installed)
			{
				stdout.printf ("Installing database schema\n");
				install ();
			}
		
			if (rc != Sqlite.OK)
			{
				throw new DatabaseError.DATABASE_NOT_OPENED("Database could not be opened");
			}
		}
	
		public void install ()
		{
			var stmt1 = prepare ("CREATE TABLE SyncedFile (
					ID INTEGER PRIMARY KEY AUTOINCREMENT,
					remoteID INTEGER(8),
					displayName VARCHAR (256),
					mimetype VARCHAR(64)
				);");
			/* VARCHAR (256) for displayName seems sensible. Most FS's only allows
			 * 256 (or less) characters (or bytes). Only a few very rarely used
			 * FS's systems allow more than this.
			 * Even then nobody will probably create a file with a that large name.
			 * Maybe some autogenerated files will have this large names, but hopefully
			 * nobody will try to sync them. If that happens, world (and this program)
			 * will collapse.
			*/
			stmt1.step ();
		
			var stmt2 = prepare ("CREATE TABLE SyncedFileTag (
					fileID INTEGER,
					tag VARCHAR (128),
					status INTEGER,
					PRIMARY KEY(fileID, tag),
					FOREIGN KEY(fileID) REFERENCES SyncedFile (ID)
						    ON DELETE CASCADE
				);");
			stmt2.step ();
		
			var stmt3 = prepare ("CREATE TABLE SyncedFileVersion (
					ID INTEGER PRIMARY KEY,
					fileID INTEGER,
					timeEdited TIMESTAMP,
					FOREIGN KEY(fileID) REFERENCES SyncedFile(ID)
					        ON DELETE CASCADE
				);");
			stmt3.step();
		
			var stmt4 = prepare ("CREATE TABLE HistoryLog (
					remoteLogID INTEGER PRIMARY KEY,
					fileRemoteID INTEGER NOT NULL,
					versionID INTEGER,
					tagName VARCHAR(128),
					isNew BOOLEAN,
					ts TIMESTAMP NOT NULL,
					local BOOLEAN NOT NULL
				);");
			stmt4.step();
			
			var stmt5 = prepare("CREATE TABLE LocalFile (
			        ID INTEGER PRIMARY KEY AUTOINCREMENT,
			        fileID INTEGER,
			        uri TEXT,
			        parentURI TEXT,
			        displayName TEXT,
			        FOREIGN KEY(fileID) REFERENCES SyncedFile(ID)
			                ON DELETE CASCADE
			    );");
			stmt5.step();
		}
	
		public Sqlite.Statement prepare(string sql)
		{
			Sqlite.Statement stmt;
			int rc = database.prepare(sql, -1, out stmt);
			return stmt;
		}
	
		public int64 last_insert_row_id()
		{
			return database.last_insert_rowid();
		}
		
		public string errmsg()
		{
			return database.errmsg();
		}
	}
	
	errordomain DatabaseError
	{
		DATABASE_NOT_OPENED,
		INSERT_ERROR
	}

}