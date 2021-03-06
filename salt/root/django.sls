#
# Django state file
#
# Deploys Django for development
#

include:
  - stackstrap.avahi
  - stackstrap.nginx
  - stackstrap.mysql.server
  - stackstrap.virtualenv
  - stackstrap.supervisor

{% from "stackstrap/utils/users.sls" import skeleton -%}
{% from "stackstrap/mysql/macros.sls" import mysql_user_db -%}
{% from "stackstrap/nginx/macros.sls" import nginxsite -%}
{% from "stackstrap/supervisor/macros.sls" import supervise -%}

{% set short_name = pillar['project']['short_name'] -%}
{% set home = "/home/vagrant" -%}
{% set virtualenv = home + "/virtualenv" -%}
{% set project = home + "/domains/" + short_name -%}
{% set appdir = home + "/domains/" + short_name + "/" + short_name -%}
{% set app_user = "vagrant" -%}
{% set app_group = "vagrant" -%}

{{ skeleton(app_user, 1000, 1000, remove_groups=False) }}

{{ short_name }}_env:
  virtualenv:
    - managed
    - name: {{ virtualenv }}
    - requirements: {{ project }}/requirements/dev.txt
    - user: vagrant
    - no_chown: True
    - system_site_packages: True
    - require:
      - pkg: virtualenv_pkgs

{{ mysql_user_db(short_name, short_name) }}

{{ nginxsite(short_name, app_user, app_group,
             template="salt://stackstrap/nginx/files/proxy-django.conf",
             server_name="_",
             create_root=False,
             defaults={
              'port': 8000,
              'handle_static': False,
              'media_path': appdir + "/media"
             })
}}

{{ supervise(short_name, home, app_user, app_group, {
        "django": {
            "command": "/bin/sh -c '" + virtualenv + "/bin/django-admin.py runserver 0:8000 2>&1'",
            "directory": appdir,
            "environment": "PYTHONPATH=\"" + appdir + "\",DJANGO_SETTINGS_MODULE=\"" + short_name + ".settings.dev\""
        }
    })
}}

{{ short_name }}_profile_setup:
  file:
    - append
    - name: /home/vagrant/.profile
    - require:
      - user: vagrant
    - text:
      - export DJANGO_SETTINGS_MODULE={{ short_name }}.settings.dev
      - export PYTHONPATH={{ appdir }}
      - source ~/virtualenv/bin/activate
      - cd /vagrant

# vim: set ft=yaml ts=2 sw=2 sts=2 et ai :
