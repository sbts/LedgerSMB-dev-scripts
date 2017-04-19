#!/bin/bash

List() {
    sudo -u postgres psql -c '
        do $$
            declare rolename text;
            begin
                for rolename in select rolname from pg_roles where rolname like '"'"'lsmb_%__%'"'"' and rolname not in ( '"'"'postgres'"'"', '"'"'lsmb_dbadmin'"'"' )
                    loop
                          RAISE NOTICE '"'"'%'"'"', rolename;
                    end loop;
        end $$;
    '
}


Drop() {
    sudo -u postgres psql -c '
        do $$
            declare rolename text;
            begin
                for rolename in select rolname from pg_roles where rolname like '"'"'lsmb_%__%'"'"' and rolname not in ( '"'"'postgres'"'"', '"'"'lsmb_dbadmin'"'"' )
                    loop
                          execute '"'"'DROP ROLE '"'"' || rolename;
                    end loop;
        end $$;
    '
}


List

echo; echo;
read -p 'Press enter to drop the listed roles, ctrl-C to abort'

Drop

