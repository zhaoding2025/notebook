

处理参数
parameters {
        string(name: 'Greeting', defaultValue: 'hwllo', description: 'How should I greet the world?')
        string(name: 'Test', defaultValue: 'demo', description: 'How should I sign the environment?')
    }
steps {
        echo '-----------------'
        echo "${params.Greeting} world INF ${name}"
        echo '-----------------'
        echo "${params.Test} environment"
    }