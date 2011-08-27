
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
	public abstract class AResource : Object
	{
		protected DBusConnection dbus_connection;
		protected string dbus_path;
		
		private uint dbus_id;
	
		protected abstract uint do_register(string path,
		                                    DBusConnection connection) throws GLib.IOError;
	
		internal virtual void publish(string path, DBusConnection connection) throws GLib.IOError
		{
			this.dbus_connection = connection;
			this.dbus_path = path;
			dbus_id = do_register(path, connection);
		}
		
		internal virtual void unpublish()
		{
			if (dbus_connection.unregister_object(dbus_id))
			{
				stdout.printf("Unregistered %s\n", dbus_path);
			}
			else
			{
				stdout.printf("Tried to unregister %s\n", dbus_path);
			}
			unpublished();
		}
		
		internal signal void unpublished();
	}
}
