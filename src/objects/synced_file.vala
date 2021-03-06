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
	[DBus (name = "be.ac.ua.comp.Barabas.SyncedFile")]
	public class SyncedFile : AResource
	{
		private Barabas.Client.SyncedFile client_synced_file;
		private Gee.Set<SyncedFileVersion> published_versions;
	
		public SyncedFile(Barabas.Client.SyncedFile client_synced_file)
		{
			this.published_versions = new Gee.HashSet<SyncedFileVersion>();
			this.client_synced_file = client_synced_file;
			this.client_synced_file.tagged.connect(on_tagged);
			this.client_synced_file.untagged.connect(on_tag_removed);
			this.client_synced_file.new_version.connect(on_new_version);
			this.client_synced_file.removed_version.connect(on_removed_version);
		}
		
		~SyncedFile()
		{
			client_synced_file.tagged.disconnect(on_tagged);
			client_synced_file.new_version.disconnect(on_new_version);
			client_synced_file.removed_version.disconnect(on_removed_version);
		}
		
		public string get_name()
		{
			return client_synced_file.display_name;
		}
		
		public string get_mimetype()
		{
			return client_synced_file.mimetype;
		}
		
		public int64 get_id()
		{
			return client_synced_file.ID;
		}
		
		public string get_local_uri()
		{
			Client.LocalFile? local_file = client_synced_file.get_local_file();
			if (local_file == null)
			{
				return "";
			}
			return local_file.uri;
		}
		
		public bool tag(string tag)
		{
			return client_synced_file.tag(tag);
		}
		
		public void untag(string tag)
		{
			client_synced_file.untag(tag);
		}
		
		public string[] tags()
		{
			return client_synced_file.tags();
		}
		
		public int64[] versions()
		{
			int64[] list = {};
			foreach (Client.SyncedFileVersion sf in client_synced_file.versions())
			{
				list += sf.ID;
			}
			return list;
		}
		
		public int64 get_latest_version()
		{
			return client_synced_file.versions().last().ID;
		}
		
		internal override void publish(string path,
		                               DBusConnection connection) throws GLib.IOError
		{
			base.publish(path, connection);
		
			foreach (Client.SyncedFileVersion sf_version in client_synced_file.versions())
			{
				publish_version(sf_version);
			}
		}
		
		internal override void unpublish()
		{
			base.unpublish();
			foreach (SyncedFileVersion version in published_versions)
			{
				version.unpublish();
			}
		}
		
		protected override uint do_register(string path,
		                                    DBusConnection connection) throws GLib.IOError
		{
			return connection.register_object(path, this);
		}
		
		public signal void tagged(string tag);
		public signal void tag_removed(string tag);
		public signal void version_added(int64 synced_file_id);
		public signal void version_removed(int64 synced_file_id);
		
		private void publish_version(Client.SyncedFileVersion sf_version) throws GLib.IOError
		{
			if (dbus_connection != null)
			{
				SyncedFileVersion version = new SyncedFileVersion(sf_version);
				version.publish(dbus_path + "/versions/" + sf_version.ID.to_string(), dbus_connection);
				published_versions.add(version);
			}
		}
		
		private void on_tagged(string tag, bool local)
		{
			tagged(tag);
		}
		
		private void on_tag_removed(string tag, bool local)
		{
			tag_removed(tag);
		}
		
		private void on_new_version(Client.SyncedFileVersion new_version, bool local)
		{
			try
			{
				publish_version(new_version);
				version_added(new_version.ID);
			}
			catch (GLib.IOError error)
			{
				// FIXME: is their something sensible we can do?
			}
		}
		
		private void on_removed_version(Client.SyncedFileVersion old_version)
		{
			version_removed(old_version.ID);
		}
	}
}
