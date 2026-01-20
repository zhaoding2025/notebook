#!/bin/bash
superset_status(){
    result=`ps -ef | awk '/gunicorn/ && !/awk/{print $2}' | wc -l`
    if [[ $result -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

superset_start(){
    source ~/.bashrc
    superset_status >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        conda activate superset; gunicorn --workers 5 --timeout 120 --bind 172.16.96.100:8787 --daemon 'superset.app:create_app()'
    else
        echo "superset 正在运行"
    fi
}

superset_stop(){
    superset_status >/dev/null 2>&1
    if [[ $? -eq 0 ]]; then
        echo "superset 未在运行"
    else
        ps -ef | awk '/gunicorn/ && !/awk/{print $2}' | xargs kill -9
    fi
}

case $1 in
    start )
        echo "启动 Superset"
        superset_start
    ;;
    stop )
        echo "停止 Superset"
        superset_stop
    ;;
    restart )
        echo "重启 Superset"
        superset_stop
        superset_start
    ;;
    status )
        superset_status > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "superset 未在运行"
        else
            echo "superset 正在运行"
        fi
esac
