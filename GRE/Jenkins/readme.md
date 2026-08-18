1、案例
# options部分输出时会带有时间
pipeline {
    agent any
    
    options {
        timestamps()                    # 日志会有时间
        skipDefaultCheckout()           # 删除隐式checkout scm语句
        disableConcurrentBuilds()          # 禁止并行
        timeout(time: 1, unit: 'HOURS')    # 指定一个小时的全局执行超时,在此之后Jenkins将中止流水线运行
    }

    stages {
        stage('Example') {
            steps {
                echo 'Hello World'
            }
        }
    }
}

二、pipeline定义
2.1 post
指定构建后操作
always{}: 总是执行脚本片段
success{}: 成功后执行
failure{}: 失败后执行
aborted{}: 取消后执行

currentBuild 是一个全局变量
    description: 构建描述

post {
        always {
            script {
                println("always")
            }
        }
        success {
            script {
                currentBuild.description += "\n 构建成功！"
            }
        }
        failure {
            script {
                currentBuild.description += "\n 构建失败！"
            }
        }
        aborted {
            script {
                currentBuild.description += "\n 构建取消！"
            }
        }
    }

三、pipeline语法
3.1 agent(代理)
agent指定了流水线的执行节点
参数:
    agent 在任何可用的节点上执行pipeline
    none  没有指定agent的时候默认
    label 在指定标签上的节点上运行pipeline
    node  允许额外的选项
# 以下两种一样
agent {node { label 'labelname' }}
agent {label 'labelname'}

3.2 post
定义一个或多个steps,这些阶段根据流水线或阶段的完成情况而运行(取决于流水线中post部分的位置),post支持以下post-condition块中的其中之一
always,changed,failure,success,unstable和aborted。这些条件块允许在post部分的步骤的执行取决于流水线或阶段的完成状态
always 无论流水线或者阶段的完成状态
changed 只有当流水线或者阶段完成状态与之前不同时
failure 只有当流水线或者阶段状态为"failure"运行
success 只有当流水线或者阶段状态为"success"运行
unstable 只有当流水线或者阶段状态为"unstable"运行。例如:测试失败
aborted 只有当流水线或者阶段状态为"aborted"运行。例如:手动取消

3.3 stages(阶段)
包含一系列一个或多个stage指令,建议stages至少包含一个stage指令用于连续交付过程的每个离散部分,比如构建,测试或部署

3.4 steps(步骤)
step是每个阶段中要执行的每个步骤

3.5 environment
environment指令指定一个键值对序列,该序列将被定义为所有步骤的环境变量,或者是特定于阶段的步骤,这取决于environment指令在流水线内的位置
该指令支持一个特殊的方法 credentials(),该方法可用于在jenkins环境中通过标识符访问预定义的凭证。对于类型为"Secret Text"的凭证
credentials() 将确保定义的环境变量包含秘密文本内容。对于类型为"Standard username and password"的凭证,指定的环境变量指定为username:password
并且两个额外的环境变量将被自动定义:分别为MYVARNAME_USER和MYVARNAME_PSW

pipeline {
    agent any
    environment {
        CC = 'zhaoding'
    }
  
    stages {
        stage('Example') {
            environment {
                AN_ACCESS_KEY = credentials('qz-api-token')
            }
            steps {
                sh 'printenv'
            }
        }
    }
}

3.6 options
options指令允许从流水线内部配置特定于流水线的选项。流水线提供了许多这样的选项,比如buildDiscarder,但也可以由插件提供,比如timestamps
buildDiscarder 为最近的流水线运行的特定数量保存组件和控制台输出
disableConcurrentBuilds 不允许同时执行流水线。可被用来防止同时访问共享资源等
overrideIndexTriggers 允许覆盖分支索引触发器的默认处理
skipDefaultCheckout 在agent指令中,跳过从源代码控制中检出代码的默认情况
skipStagesAfterUnstable 一旦构建状态变得Unstable 跳过该阶段
checkoutToSubdirectory 在工作空间的子目录中自动地执行源代码控制检出
timeout 设置流水线运行的超时时间 在此之后 Jenkins将中止流水线
retry 在失败时 重新尝试整个流水线的指定次数
timestamps 预测所有由流水线生成的控制台输出 与该流水线发出的时间一致

3.7 paramters(参数)
为流水线运行时设置项目相关的参数
string 字符串类型的参数 例如:
parameters{ string(name: 'DEPLOY_ENV', defaultValue: 'staging', description: '')}
booleanParam 布尔参数 例如：
parameters{ booleanParam(name: 'DEBUG_BUILD', defaultValue: true, description: '')}

pipeline {
    agent any
    parameters { 
        string(name: 'DEPLOY_ENV', defaultValue: 'zhaoding', description: '')
    }
    stages {
        stage('Example') {
            steps {
                echo "Hello ${params.DEPLOY_ENV}"
            }
        }
    }
}

3.8 trigger(触发器)
构建触发器
cron计划任务定期执行构建
triggers { cron('H */4 * * 1-5') }
pollSCM与cron定义类似,但是由jenkins定期检测源码变化
triggers { pollSCM('H */4 * * 1-5') }
upstream接受逗号分隔的工作字符串和阈值。当字符串中的任何作业以最小阈值结束时,流水线被重新触发
triggers { upstream(upstreamProjects: 'job1,job2', threshold: hudson.model.Result.SUCCESS) }

3.9 tool
获取通过自动安装或手动放置工具的环境变量。支持maven/jdk/gradle。工具的名称必须在系统设置->全局工具配置中定义
pipeline {
    agent any
    tools {
        maven 'mvn-3.9.16'
    }   
    
    stages {
        stage('Example') {
            steps {
                sh 'mvn --version'
            }
        }
    }
}

3.10 input
input用户在执行各个阶段的时候,由人工确定是否继续进行
 message 呈现给用户的提示信息
 id 可选,默认为stage名称
 ok 默认表单上的ok文本
 submitter 可选的,以逗号分隔的用户列表或允许提交的外部组名。默认允许任何用户
 submitterParameter 环境变量的可选名称。如果存在,用submitter名称设置
 parameters 提示提交者提供的一个可选的参数列表

pipeline {
    agent any

    stages {
        stage('Example') {
            input {
                message "Should we continue?"
                ok "Yes,wu should"
                submitter "alice,bob"
                parameters {
                    string(name: 'PERSON', defaultValue: 'Mr Jenkins', description: 'Who should I say')
                }
            }
            steps {
                echo "Hello，${PERSON},nice to meet you."
            }
        }
    }
}

3.11 when
when指令允许流水线根据指定的条件决定是否应该执行阶段。when指令必须包含至少一个条件。如果when指令包含多个条件,所有的子条件必须返回True,阶段才能执行
这与子条件在allOf条件下嵌套的情况相同
内置条件：
    branch: 当正在构建的分支与模式给定的分支匹配时,执行这个阶段,这只适用于多分支流水线 例如：
        when { branch 'master' }
    environment: 当指定的环境变量是给定的值时,执行这个步骤 例如:
        when { environment name: 'DEPLOY_TO', value: 'production' }
    expression: 当指定的Groovy表达式评估为true时,执行这个阶段 例如:
        when { expression { return params.DEBUG_BUILD }}
    not: 当嵌套条件是错误时,执行这个阶段,必须包含一个条件,例如:
        when { not { branch 'master' }}
    allOf: 当所有的嵌套条件都正确时,执行这个阶段,必须包含至少一个条件,例如:
        when { allOf { branch 'master': environment name: 'DEPLOY_TO', value: 'production' }}
    anyOf: 当至少有一个嵌套条件为真时,执行这个阶段,必须包含至少一个条件,例如:
        when { anyOf { branch 'master': branch 'staging' }}

3.12 parallel 并行
声明式流水线的阶段可以在他们内部声明多嵌套阶段,他们将并行执行。注意,一个阶段必须只有一个steps或parallel的阶段。嵌套阶段本身不能包含进一步的parallel阶段
但是其他的阶段的行为与任何其他stage parallel的阶段不能包含agent或tools阶段,因为他们没有相关steps
另外,通过添加failFast true到包含parallel的stage中,当其中一个进程失败时,可以强制所有的parallel阶段都被终止

3.13 step步骤
script步骤需要[scripted-pipeline]块并在声明式流水线中执行。对于大多数用例来说,应该声明式流水线中的“脚本”步骤是不必要的,但是它可以提供一个有用的“逃生出口”
非平凡的规模和/或复杂性的script块应该被转移到共享库
pipeline {
    agent any

    stages {
        stage('Example') {
            steps {
                script {
                    def browsers = ['chrome', 'firefox']
                    for (int i = 0; i < browsers.size(); ++i){
                        echo "Testing the ${browsers[i]} browser"
                    }
                }
            }
        }
    }
}

四、Jenkins共享库
JenkinsShareLibrary概述
src 目录类似于标准java源目录结构。执行流水线时,此目录将添加到类路径中
vars 目录托管脚本文件,这些脚本文件在"管道"中作为变量公开
resources 目录允许libraryResource从外部库中使用步骤来加载相关联的非Groovy文件

(root)
+-src           # Groovy source files
|   +- org
|       +- foo
|           +- Bar.groovy   # for org.foo.Bar class
+- vars
|   +- foo.groovy       # for global 'foo' variable
|   +- foo.txt          # help for 'foo' variable
+- resources            # resource files (external libraries only)
|   +- org
|       +- foo
|           +- bar.json # static helper data for org.foo.Bar

4.1 使用库
标记为Load的共享库隐含的允许管道立即使用任何此类库定义的类或全局变量。要访问其他共享库,Jenkinsfile需要标记@library注释,并指定库的名称
@Library('my-shared-library')
# 参考jenkinslib
安装ansicolor
//格式化输出
def PrintMes(value,color){
    colors = [
        'red'   : "\033[40;31m >>>>>>>>>>>${value}<<<<<<<<<< \033[0m",
        'blue'  : "\033[47;34m ${value} \033[0m",
        'green' : "\033[1;32m>>>>>>>>>>>${value}>>>>>>>>>>>\033[0m",
        'green1': "\033[40;32m >>>>>>>>>>>${value}<<<<<<<<<< \033[0m"
    ]
    ansiColor('xterm') {
        echo colors[color] ?: value
    }
}

五、Groovy基础语法
5.1 Groovy数据类型
string
字符串表示： 单引号、双引号、三引号
常用方法：
contains () 是否包含特定内容 返回 true false
size () length () 字符串数量大小长度
toString () 转换成 string 类型
indexOf () 元素的索引
endsWith () 是否指定字符结尾
minus () plus () 去掉、增加字符串
reverse () 反向排序
substring (1,2) 字符串的指定索引开始的子字符串
toUpperCase () toLowerCase () 字符串大小写转换
split () 字符串分割 默认空格分割 返回列表

list
列表符号： []
常用方法
+= -= 元素增加减少
add () << 添加元素
isEmpty () 判断是否为空
intersect ([2,3]) disjoint ([1]) 取交集、判断是否有交集
flatten () 合并嵌套的列表
unique () 去重
reverse () sort () 反转 升序
count () 元素个数
join () 将元素按照参数链接
sum () min () max () 求和 最小值 最大值
contains () 包含特定元素
remove(2) removeAll()
each {} 遍历

5.2 groovy函数
def 定义函数
语法:
    def PrintMes(value){
        println(value)
        //xxxx
        return value
    }













