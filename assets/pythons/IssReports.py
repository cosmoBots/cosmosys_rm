#!/usr/bin/env python
# coding: utf-8

# In[ ]:

import sys
import json
from datetime import datetime

def tree_to_list(tree,parentNode):
    result = []
    #print("\n\n\n******ARBOL******* len= ",len(tree))
    for node in tree:
        node['chapters'] = []
        node['issues'] = []
        #print("\n\n\n******NODO*******",node['id'])

        if 'type' in node.keys():
            if (node['type'] == "Info"):
                # Nos encontramos en un nodo del tipo informacion, para el que no vamos a 
                # querer, posiblemente, generar tablas de atributos.  Para que Carbone
                # pueda filtrar facilmente este tipo de datos, le anyadiremos la propiedad
                # infoType = 1.
                node['infoType'] = 1
                if (parentNode != None):
                    parentNode['chapters'].append(node)

            else:
                node['infoType'] = 0
                if (parentNode != None):
                    parentNode['issues'].append(node)

        else:
            node['infoType'] = 0
            if (parentNode != None):
                parentNode['issues'].append(node)


        #print(node['subject'])
        node['status'] = data['statuses'][str(node['status_id'])]
        if 'fixed_version_id' in node.keys():
            if (node['fixed_version_id'] is not None):
                if (node['fixed_version_id'] in data['targets'].keys()):
                    node['target'] = data['targets'][str(node['fixed_version_id'])]

        node['tracker'] = data['trackers'][str(node['tracker_id'])]
        purgednode = node.copy()
        purgednode['children'] = []

        # Rellenamos la tabla de dependencias inversa, para que 
        # los nodos encuentren aquellos de los que dependen
        for r in node['relations']:
            if str(r['issue_to_id']) not in data['dependents'].keys():
                data['dependents'][str(r['issue_to_id'])] = []

            data['dependents'][str(r['issue_to_id'])].append(node['id'])     

        #print(purgednode)
        result.append(purgednode)
        result += tree_to_list(node['children'],node)

    return result

def propagate_dependence_up(node,firstdependable,currentdependable,server_url,dependents):
    if 'valid' in node.keys():
        if (node['valid']):
            colorstr = "black"
        else:
            colorstr = "red"
    else:
        colorstr = "black"

    nodelabel = "{" + node['subject'] + "|" + node['title'] + "}"
    diagrams[str(currentdependable)]['self_d'].node(str(node['id']), nodelabel, URL=server_url+'/issues/'+str(node['id']), tooltip=node['description'], fillcolor='grey', color=colorstr)

    #print("Up: ",node['id']," <- ",firstdependable," <- ... <- ",currentdependable)
    if currentdependable != firstdependable:
        # Tebenos que añadirnos al diagraa del precursor
        diagrams[str(currentdependable)]['self_d'].edge(str(firstdependable), str(node['id']),color="blue")

    #print(dependents)
    if str(currentdependable) in dependents.keys():
        #print("entro")
        for dep in dependents[str(currentdependable)]:
            propagate_dependence_up(node,firstdependable,dep,server_url,dependents)


def propagate_dependence_down(node,firstdependent,currentdependent,server_url,issueslist):
    # Buscanos el nodo actual
    #print("Down: ",node['id']," -> ",firstdependent," -> ... -> ",currentdependent)
    for n in issueslist:
        if n['id'] == currentdependent:
            break

    #print(n)

    if (firstdependent != currentdependent):
        if 'valid' in node.keys():
            if (node['valid']):
                colorstr = "black"
            else:
                colorstr = "red"
        else:
            colorstr = "black"

        #print("***************","entro!","*****************")
        nodelabel = "{" + node['subject'] + "|" + node['title'] + "}"
        diagrams[str(currentdependent)]['self_d'].node(str(node['id']), nodelabel, URL=server_url+'/issues/'+str(node['id']), tooltip=node['description'], fillcolor='grey',color=colorstr)

        #print(node['id']," -> ",firstdependent," ->...-> ",currentdependent)
        # Tebenos que añadirnos al diagraa del precursor
        diagrams[str(currentdependent)]['self_d'].edge(str(node['id']),str(firstdependent),color="blue")
        #print("entro")
    
    for dep in n['relations']:
        propagate_dependence_down(node,firstdependent,dep['issue_to_id'],server_url,issueslist)


def generate_diagrams(node,diagrams,ancestors,server_url,dependents):

    # Añadimos las URLs de los graficos del nodo al propio nodo
    node['url_h'] = diagrams[str(node['id'])]['url_h']
    node['url_d'] = diagrams[str(node['id'])]['url_d']
    # Get current graph
    #print(str(node['id']),node['subject'])
    # Dibujamos el nodo actual en los grafos generales
    if 'valid' in node.keys():
        if (node['valid']):
            colorstr = "black"
        else:
            colorstr = "red"
    else:
        colorstr = "black"

    nodelabel = "{" + node['subject'] + "|" + node['title'] + "}"
    diagrams['project']['self_h'].node(str(node['id']), nodelabel, URL=server_url+'/issues/'+str(node['id']), tooltip=node['description'], fillcolor='grey',color=colorstr)

    # Si tiene padre, pintaremos el vertice entre el padre y él
    if (len(ancestors)>0):
        parentissue = ancestors[0]
        diagrams['project']['self_h'].edge(str(parentissue['id']), str(node['id']))
    else:
        parentissue = None

    # Si este nodo tiene relaciones o ha sido marcado como dependiente, lo añadimos en el grafo geneal
    if str(node['id']) in dependents.keys():
        dependables = dependents[str(node['id'])]
        #print(dependables)
    else:
        dependables = None

    if (len(node['relations']) > 0) or (dependables is not None):
        if 'valid' in node.keys():
            if (node['valid']):
                colorstr = "black"
            else:
                colorstr = "red"
        else:
            colorstr = "black"
        

        diagrams['project']['self_d'].node(str(node['id']), nodelabel, URL=server_url+'/issues/'+str(node['id']), tooltip=node['description'], fillcolor='grey', color=colorstr)

        # En caso de tratarse de un nodo dependiente, lo añadiremos a los diagramas de los nodos precursores
        #print("Relaciones tiene")
        if (dependables is not None):
            for pr in dependables:
                #print("propago ",node['id'],": ",node['subject'])
                # Debemos también recorrer de manera arbórea todos aquellos nodos en la cadena de depndencia
                propagate_dependence_up(node,pr,pr,server_url,dependents)

    # Para cada relación
    for r in node['relations']:
        # añadiremos un eje en el grafo general
        diagrams['project']['self_d'].edge(str(node['id']), str(r['issue_to_id']), color="blue")
        # En el grafo del dependiente añadiremos el nodo como precursor
        if 'valid' in node.keys():
            if (node['valid']):
                colorstr = "black"
            else:
                colorstr = "red"
        else:
            colorstr = "black"
        

        diagrams[str(r['issue_to_id'])]['self_d'].node(str(node['id']), nodelabel, URL=server_url+'/issues/'+str(node['id']), tooltip=node['description'], fillcolor='grey', color=colorstr)

        diagrams[str(r['issue_to_id'])]['self_d'].edge(str(node['id']), str(r['issue_to_id']), color="blue")
        # En nuestro propio grafo añadiremos una arista hacia el nodo dependiente
        diagrams[str(node['id'])]['self_d'].edge(str(node['id']), str(r['issue_to_id']), color="blue")

        # Ahora propagaremos el cambio hacia abajo para que en los diagramas de los dependientes
        # a más de un nivel aparezca el nodo actual y la dependencia con la relacion de primer 
        # nivel
        propagate_dependence_down(node,r['issue_to_id'],r['issue_to_id'],server_url,issueslist)


    # Ahora pintamos el camino de los ancestros en el grafo correspondiente al nodo actual
    desc = node
    graph = diagrams[str(node['id'])]['self_h']
    for anc in ancestors:
        # Dibujamos el nodo del ancestro y el link a sus descendiente en el grafo actual
        if 'valid' in anc.keys():
            if (anc['valid']):
                colorstr = "black"
            else:
                colorstr = "red"
        else:
            colorstr = "black"
        


        nodelabel = "{"+anc['subject']+"|"+anc['title']+"}"
        graph.node(str(anc['id']),nodelabel,URL=server_url+'/issues/'+str(anc['id']),tooltip=anc['description'], fillcolor='grey', color=colorstr)

        graph.edge(str(anc['id']),str(desc['id']))
        #print("en el grafo de ",node['subject']," meto un ancestro",anc['subject']," como padre de ",desc['subject'])
        # Dibujamos el nodo actual en el grafo del ancestro, con un vínculo a su padre
        graphanc = diagrams[str(anc['id'])]['self_h']

        if 'valid' in node.keys():
            if (node['valid']):
                colorstr = "black"
            else:
                colorstr = "red"
        else:
            colorstr = "black"
        


        nodelabel = "{" + node['subject'] + "|" + node['title'] + "}"
        graphanc.node(str(node['id']),nodelabel,URL=server_url+'/issues/'+str(node['id']),tooltip=node['description'], fillcolor='grey', color=colorstr)


        if (parentissue is not None):
            graphanc.edge(str(parentissue['id']),str(node['id']))
            #print("En el grafo de ",anc['subject']," meto un nodo descendiente ",node['subject'],"conectado con su padre ",parentissue['subject'])
        
        # El ancestro actual pasa a ser el descendiente del ancestro siguiente 
        desc = anc

    for child in node['children']:
        #if ((parentissue is None) or (child['doc_id']!=parentissue['doc_id'])):
        # Solo vamos a generar diagramas cuando bajemos desde el documento que los contiene,
        # Esto lo detectamos cuando el doc al que pertenece el hijo es diferente al que pertenece el padre
        generate_diagrams(child,diagrams,[node]+ancestors,server_url,dependents)


#print ("This is the name of the script: ", sys.argv[0])
#print ("Number of arguments: ", len(sys.argv))
#print ("The arguments are: ", str(sys.argv))

#my_project['url'] = 'http://localhost:5555'           # The Redmine URL
#issues_key_txt = 'd32df1cc535477adb95998fb4633bc50e8e664e3'    # The API key of the user (or bot) in which name the actions are undertaken.


# pr_id_str = issues_project_id_str
pr_id_str = sys.argv[1]
#print("id: ",pr_id_str)

# reporting_path = reporting_dir
reporting_path = sys.argv[2]
#print("reporting_path: ",reporting_path)

# img_path = img_dir
img_path = sys.argv[3]
#print("img_path: ",img_path)

# root_url = issues_server_url
root_url = sys.argv[4]
#print("root_url: ",root_url)

tmpfilepath = None
if (len(sys.argv) > 5):
    # tmpfilepath
    tmpfilepath = sys.argv[5]
    #print("tmpfilepath: ",tmpfilepath)

if (tmpfilepath is None):
    import json,urllib.request
    urlfordata = root_url+"/cosmosys/"+pr_id_str+".json?key="+issues_key_txt
    #print("urlfordata: ",urlfordata)
    datafromurl = urllib.request.urlopen(urlfordata).read().decode('utf-8')
    data = json.loads(datafromurl)

else:
    import json
    with open(tmpfilepath, 'r', encoding="utf-8") as tmpfile:
        data = json.load(tmpfile)


my_project = data['project']
my_project['chapters'] = []
my_project['issues'] = []

#print ("Obtenemos proyecto: ", my_project['id'], " | ", my_project['name'])

issues = data['issues']
targets = data['targets']
statuses = data['statuses']
# Ahora vamos a generar los diagramas de jerarquía y de dependencia para cada una de los issues, y los guardaremos en la carpeta doc.
#print("len(issues)",len(issues))
# Debemos preparar un diagrama para cada nodo
#print("#####Vamos con los documentos!!!!")
data['dependents'] = {}
issueslist = tree_to_list(issues,my_project)
data['issueslist'] = issueslist

data['issuesclean'] = []
data['byperson'] = {}

lower_reporting_period = None
upper_reporting_period = None
lower_reporting_period_id = None
upper_reporting_period_id = None

for tk in data['targets']:
    t = data['targets'][tk]
    t['issues'] = []
    if 'start_date' in t.keys():
        if (t['start_date'] is not ''):
            #print(t)
            #print(t['start_date'])
            #print(datetime.strptime(t['start_date'], '%Y-%m-%d'))
            #print(datetime.strptime(t['start_date'], '%Y-%m-%d').timestamp())
            #print(int(datetime.strptime(t['start_date'], '%Y-%m-%d').timestamp()))
            t['start_date_int'] = int(datetime.strptime(t['start_date'], '%Y-%m-%d').timestamp())
            if 'due_date' in t.keys():
                if (t['due_date'] is not ''):
                    t['due_date_int'] = int(datetime.strptime(t['due_date'], '%Y-%m-%d').timestamp())

    # Lets know the reporting periods
    if t['status'] == "open":
        if lower_reporting_period is None:
            # First open period
            # The first is considered the first "lower"
            lower_reporting_period = t
            lower_reporting_period_id = tk
        else:
            if upper_reporting_period is None:
                # Second open period
                if 'due_date_int' in t.keys():
                    if t['due_date_int'] < lower_reporting_period['due_date_int']:
                        # It is lower than the lowest, so this will be the new
                        # lowest, and the previous lowest will be the second lowest
                        upper_reporting_period = lower_reporting_period
                        upper_reporting_period_id = lower_reporting_period_id
                        lower_reporting_period = t
                        lower_reporting_period_id = tk
                    else:
                        # It is higher, so it is considered the second lowest
                        upper_reporting_period = t
                        upper_reporting_period_id = tk
                
            else:
                if 'due_date_int' in t.keys():
                    # 3... open period
                    if t['due_date_int'] < lower_reporting_period['due_date_int']:
                        # It is the new lowest, so the lowest will now be the 
                        # second lowest
                        upper_reporting_period = lower_reporting_period
                        upper_reporting_period_id = lower_reporting_period_id
                        lower_reporting_period = t
                        lower_reporting_period_id = tk
                    else:
                        if t['due_date_int'] < upper_reporting_period['due_date_int']:
                            # It is not the lowest but the second lowest
                            upper_reporting_period = t
                            upper_reporting_period_id = tk


print("Salimos de los targets")

for r in issueslist:
    #print(r)
    if 'start_date' in r.keys():
        if(r['start_date']):
            #print(r)
            #print(r['start_date'])
            #print(datetime.strptime(r['start_date'], '%Y-%m-%d'))
            #print(datetime.strptime(r['start_date'], '%Y-%m-%d').timestamp())
            #print(int(datetime.strptime(r['start_date'], '%Y-%m-%d').timestamp()))
            r['start_date_int'] = int(datetime.strptime(r['start_date'], '%Y-%m-%d').timestamp())
    if 'due_date' in r.keys():
        if(r['due_date']):
            r['due_date_int'] = int(datetime.strptime(r['due_date'], '%Y-%m-%d').timestamp())

    if 'type' in r.keys():
        if r['type'] != 'Info':
            data['issuesclean'].append(r)            
            sdt = None
            ddt = None
            if 'start_date_int' in r.keys():
                sdt = r['start_date_int']

            if 'due_date_int' in r.keys():
                ddt = r['due_date_int']

            periods = []

            include_none = True
            for tk in data['targets']:
                if 'start_date_int' in t.keys():
                    t = data['targets'][tk]
                    include_period = True
                    finish_check = True
                    if sdt != None or ddt != None:
                        finish_check = False
                        psdt = None
                        pddt = None
                        if 'start_date_int' in t.keys():
                            psdt = t['start_date_int']

                        if 'due_date_int' in t.keys():
                            pddt = t['due_date_int']

                        if sdt != None and pddt != None:
                            if sdt > pddt:
                                include_period = False
                                finish_check = True

                        if not finish_check:
                            if ddt != None and psdt != None:
                                if ddt < psdt:
                                    include_period = False
                                    finish_check = True

                    if include_period:
                        include_none = False
                        periods.append(tk)

                if include_none:
                    periods.append('none')

            r['periods'] = periods

            if 'assigned_to' in r.keys():
                people = r['assigned_to']
                for personkey in people:
                    if (personkey == ""):
                        personkey = "nobody"
                    if personkey not in data['byperson'].keys():
                        data['byperson'][personkey] = {}
                        if personkey in data['members'].keys():
                            data['byperson'][personkey]['gen_report'] = data['members'][personkey]['gen_report']
                        else:
                            data['byperson'][personkey]['gen_report'] = False

                        data['byperson'][personkey]['targets'] = {}
                        for p in data['targets']:
                            data['byperson'][personkey]['targets'][p] = {}
                            data['byperson'][personkey]['targets'][p]['assigned'] = []
                            data['byperson'][personkey]['targets'][p]['supervised'] = []
                    #print("*********************1")
                    #print(periods)
                    #print("*********************2")
                    #print(data['byperson'][personkey]['targets'].keys())                        
                    #print("*********************3")
                    #print(r)
                    #print("*********************4")
                    for p in periods:
                        if (p not in data['byperson'][personkey]['targets'].keys()):
                            data['byperson'][personkey]['targets'][p] = {}
                            data['byperson'][personkey]['targets'][p]['assigned'] = []
                            data['byperson'][personkey]['targets'][p]['supervised'] = []

                        data['byperson'][personkey]['targets'][p]['assigned'].append(r)

            if 'supervisor' in r.keys():
                personkey=r['supervisor']
                if (personkey == ""):
                    personkey = "nobody"
                if personkey not in data['byperson'].keys():
                    data['byperson'][personkey] = {}
                    if personkey in data['members'].keys():
                        data['byperson'][personkey]['gen_report'] = data['members'][personkey]['gen_report']
                    else:
                        data['byperson'][personkey]['gen_report'] = False

                    data['byperson'][personkey]['targets'] = {}
                    for p in data['targets']:
                        data['byperson'][personkey]['targets'][p] = {}
                        data['byperson'][personkey]['targets'][p]['assigned'] = []
                        data['byperson'][personkey]['targets'][p]['supervised'] = []
                        
                #print("*********************")
                #print(periods)
                #print("*********************")
                #print(data['byperson'][personkey]['targets'].keys())
                for p in periods:                            
                    if (p not in data['byperson'][personkey]['targets'].keys()):
                        data['byperson'][personkey]['targets'][p] = {}
                        data['byperson'][personkey]['targets'][p]['assigned'] = []
                        data['byperson'][personkey]['targets'][p]['supervised'] = []

                    data['byperson'][personkey]['targets'][p]['supervised'].append(r)



#print("len(issueslist)",len(issueslist))

# Ahora recorremos el proyecto y sacamos los diagramas completos de jerarquía y dependencias, y guardamos los ficheros de esos diagramas en la carpeta doc.

# In[ ]:
diagrams = {}

from graphviz import Digraph

path_root = img_path + "/" + my_project['identifier'] + "_"

parent_g_h = Digraph(name=path_root + "h", format='svg', strict=True,
                           graph_attr={'ratio': 'compress', 'size': '9,5,30', 'margin': '0'}, engine='dot',
                           node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})
self_g_h = Digraph(name="clusterH",
                    graph_attr={'labeljust': 'l', 'labelloc': 't', 'label': 'Hierarchy', 'margin': '5'}, engine='dot',
                    node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})
parent_g_d = Digraph(name=path_root + "d", format='svg', strict=True,
                            graph_attr={'ratio': 'compress', 'size': '9.5,30', 'margin': '0'}, engine='dot',
                            node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})
self_g_d = Digraph(name="clusterD",
                     graph_attr={'labeljust': 'l', 'labelloc': 't', 'label': 'Dependences', 'margin': '5'},
                     engine='dot', node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})

url_base = root_url+"/projects/"+pr_id_str+"/repository/rq/revisions/master/raw/reporting/doc/"+"./img/" + my_project['identifier'] + "_"
url_sufix = ".gv.svg"
url_h = url_base +"h"+url_sufix
url_d = url_base +"d"+url_sufix
my_project['url_h'] = url_h
my_project['url_d'] = url_d
diagrams['project'] = {'url_h':url_h, 'url_d':url_d, 'parent_h': parent_g_h, 'self_h': self_g_h, 'parent_d': parent_g_d, 'self_d': self_g_d, }

import os

#print(issueslist)
# Generamos los diagramas correspondientes a los issues del proyecto
for my_issue in issueslist:
    #print("\n\n---------- Diagrama ----------", my_issue['subject'])
    path_root = img_path + "/" + str(my_issue['id']) + "_"

    parent_h = Digraph(name=path_root + "h", format='svg',
                                graph_attr={'ratio': 'compress', 'size': '9.5,30', 'margin': '0'}, engine='dot',
                                node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})

    self_h = Digraph(name="clusterH",
                         graph_attr={'labeljust': 'l', 'labelloc': 't', 'label': 'Hierarchy', 'margin': '5'},
                         engine='dot', node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})
    
    parent_d = Digraph(name=path_root + "d", format='svg',
                                graph_attr={'ratio': 'compress', 'size': '9.5,30', 'margin': '0'}, engine='dot',
                                node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})
    self_d = Digraph(name="clusterD",
                         graph_attr={'labeljust': 'l', 'labelloc': 't', 'label': 'Dependences', 'margin': '5'},
                         engine='dot', node_attr={'shape': 'record', 'style': 'filled', 'URL': my_project['url']})
    url_base = root_url+"/projects/"+pr_id_str+"/repository/rq/revisions/master/raw/reporting/doc/"+"./img/" + str(my_issue['id']) + "_"
    url_sufix = ".gv.svg"
    url_h = url_base +"h"+url_sufix
    url_d = url_base +"d"+url_sufix
    my_issue['url_h'] = url_h
    my_issue['url_d'] = url_d

    # Pinto cada nodo en su diagrama
    #print("Creo los diagrama con id ",my_issue['id'])
    diagrams[str(my_issue['id'])] = {'url_h':url_h, 'url_d':url_d, 'parent_h': parent_h, 'self_h': self_h, 'parent_d': parent_d, 'self_d': self_d, }

    if 'valid' in my_issue.keys():
        if (my_issue['valid']):
            colorstr = "black"
        else:
            colorstr = "red"
    else:
        colorstr = "black"
    

    nodelabel = "{" + my_issue['subject'] + "|" + my_issue['title'] + "}"
    self_h.node(str(my_issue['id']), nodelabel, URL=my_project['url'] + '/issues/' + str(my_issue['id']),
                    fillcolor='green', tooltip=my_issue['description'], color=colorstr)
    

    title_str = my_issue['title']

    nodelabel = "{" + my_issue['subject'] + "|" + title_str + "}"
    self_d.node(str(my_issue['id']), nodelabel, URL=my_project['url'] + '/issues/' + str(my_issue['id']), fillcolor='green',
                    tooltip=my_issue['description'], color=colorstr)


# Ahora recorrere todo el arbol rellenando los nodos en cada diagrama

#print(diagrams)

for rq in issues:
    generate_diagrams(rq,diagrams,[],my_project['url'],data['dependents'])

for my_issue in issueslist:
    #print(my_issue)
    prj_graphc_parent = diagrams[str(my_issue['id'])]['parent_h']
    prj_graphc = diagrams[str(my_issue['id'])]['self_h']
    prj_graphc_parent.subgraph(prj_graphc)
    prj_graphc_parent.render()
    '''
    symlink_path = img_path + "/" + my_issue['subject'] + "_" + "h.gv.svg"
    #print("file: ", path_root + "h.gv.svg")
    #print("symlink: ", symlink_path)
    if (os.path.islink(symlink_path)):
        os.remove(symlink_path)

    os.symlink(path_root + "h.gv.svg", symlink_path)
    '''

    prj_graphd_parent = diagrams[str(my_issue['id'])]['parent_d']
    prj_graphd = diagrams[str(my_issue['id'])]['self_d']
    prj_graphd_parent.subgraph(prj_graphd)
    prj_graphd_parent.render()

    '''
    symlink_path = img_path + "/" + my_issue['subject'] + "_" + "d.gv.svg"
    #print("file: ", path_root + "d.gv.svg")
    #print("symlink: ", symlink_path)
    if (os.path.islink(symlink_path)):
        os.remove(symlink_path)

    os.symlink(path_root + "d.gv.svg", symlink_path)
    '''

parent_g_h.subgraph(self_g_h)
parent_g_h.render()
parent_g_d.subgraph(self_g_d)
parent_g_d.render()

#print("project hierarchy diagram file: ", path_root + "h.gv.svg")
#print("project dependence diagram file: ", path_root + "d.gv.svg")

#print("Acabamos")

# Vamos a grabar el fichero JSON intermedio para generar los reportes

# In[ ]:


datadoc = data

import json

print("Preparamos el fichero JSON que usaremos de puente para generar la documentación")

with open(reporting_path + '/doc/issues.json', 'w') as outfile:
    json.dump(datadoc, outfile)

#print("Acabamos")

# Lanzamos la herramienta Carbone en Node, para generar los reportes de documentación.

# In[ ]:


from Naked.toolshed.shell import execute_js


period = lower_reporting_period_id
nextPeriod = upper_reporting_period_id

datelim11 = int(datetime.strptime(data['targets'][period]['start_date'], '%Y-%m-%d').timestamp())
datelim12 = int(datetime.strptime(data['targets'][period]['due_date'], '%Y-%m-%d').timestamp())
datelim21 = int(datetime.strptime(data['targets'][nextPeriod]['start_date'], '%Y-%m-%d').timestamp())
datelim22 = int(datetime.strptime(data['targets'][nextPeriod]['due_date'], '%Y-%m-%d').timestamp())
print("Datelim11: ",data['targets'][period]['start_date']," ",datelim11)
print("Datelim12: ",data['targets'][period]['due_date']," ",datelim12)
print("Datelim21: ",data['targets'][nextPeriod]['start_date']," ",datelim21)
print("Datelim22: ",data['targets'][nextPeriod]['due_date']," ",datelim22)


success = execute_js('./plugins/cosmosys/assets/pythons/lib/launch_carbone.js', reporting_path
    + " " + data['project']['identifier'] + " \'" + data['project']['name'] + "\' "+"0"
    + " " + period + " " + nextPeriod
    + " " + str(datelim11) + " " + str(datelim12)
    + " " + str(datelim21) + " " + str(datelim22)
    )
#print(success)

if success:
    # handle success of the JavaScript
    print("Todo fue bien")

else:
    # handle failure of the JavaScript
    print("todo fue mal")

# js_command = 'node ' + file_path + " " + arguments
#print(reqdocs.keys())

print("INFORMES")
for person in data['byperson'].keys():
    print("Generando infome de ",person)
    if (data['byperson'][person]['gen_report']):
        success = execute_js('./plugins/cosmosys/assets/pythons/lib/launch_carbone.js', reporting_path
            + " " + person + " " + person + " "+"1"
            + " " + period + " " + nextPeriod
            + " " + str(datelim11) + " " + str(datelim12)
            + " " + str(datelim21) + " " + str(datelim22)
            )
        #print(success)

        if success:
            # handle success of the JavaScript
            print("Todo fue bien")

        else:
            # handle failure of the JavaScript
            print("todo fue mal")

    else:
        print("skipping",person)
# Vamos a generar el archivo JSON para crear el árbol

# In[ ]:


import json


# Preparamos el fichero JSON que usaremos para el árbol

def create_tree(current_issue):
    #print("issue: " + current_issue['subject'])
    descr = getattr(current_issue, 'description', current_issue['subject'])
    tree_node = {'title': current_issue.custom_fields.get(
        issues_chapter_cf_id).value + ": " + current_issue['subject'] + ": " + current_issue.custom_fields.get(
        issues_title_cf_id).value,
                 'subtitle': descr,
                 'expanded': True,
                 'children': [],
                 }
    chlist = redmine.issue.filter(project_id=pr_id_str, parent_id=current_issue['id'], status_id='*')
    childrenitems = sorted(chlist, key=lambda k: k['chapter'])
    for c in childrenitems:
        child_issue = redmine.issue.get(c['id'])
        child_node = create_tree(child_issue)
        tree_node['children'].append(child_node)

    return tree_node


#print("Acabamos")

# In[ ]:
