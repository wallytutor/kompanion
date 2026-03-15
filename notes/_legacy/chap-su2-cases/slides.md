---
jupyter:
  jupytext:
    cell_metadata_filter: -all
    formats: md,ipynb
    text_representation:
      extension: .md
      format_name: markdown
      format_version: '1.3'
      jupytext_version: 1.18.1
  kernelspec:
    display_name: Python 3 (ipykernel)
    language: python
    name: python3
---

# CFD pour tous


## Importation des outils

```python
%load_ext autoreload
%autoreload 2
```

```python
import majordome.latex as ml
```

## Création du *handle*

```python
config = {
    "template": "slides",
    "graphicspath": "../media",
    "title": "CFD pour tous",
    "subtitle": "Introduction à la dynamique des fluides numérique avec SU2",
    "author": "Walter Dal'Maz Silva",
    "date": "\\today"
}

slides = ml.BeamerSlides(config=config, verbose=False)
```

```python
def new_slide(key, **kw):
    """ Wrapper to create slides with section title. """
    slides.add_slide(key, title="\\insertsection",
                     subtitle=kw.pop("title"), **kw)
```

## Introduction

```python
slides.add_section("Introduction")
```

### Objectifs de la formation

```python
title = "Objectifs de la formation"

with ml.Itemize(itemsep="3pt") as item:
    item.add("Présenter le logiciel SU2, ses fonctionalités, et outils d'appui à son usage")
    item.add("Vulgariser la pratique du calcul CFD pour les écoulements monophasés")
    item.add("Introduire les éléments de base de conception géométrique et de maillage")
    items1 = item.collect()

with ml.Itemize(itemsep="3pt") as item:
    item.intro("Il n'est pas parmi nos objectifs de : ")
    item.add("Créer des extensions en C++ pour logiciel SU2 (ajouter des modèles)")
    item.add("...")
    items2 = item.collect()

with ml.SlideContentWriter() as writer:
    writer.add(items1)
    writer.vspace("6mm")
    writer.add(items2)
    contents = writer.collect()

new_slide("intro_objectifs", title=title, contents=contents)
```

### Pré-requis pour suivre cette formation

```python
title = "Pré-requis pour suivre cette formation"

with ml.Itemize(itemsep="3pt") as item:
    item.add("Formation en sciences de l'ingénieur avec bases solids en mécanique de fluides")
    item.add("Ouverture de sprit pour se lancer dans le monde de la \\emph{ligne de commande}")
    item.add("Avoir un PC tournant sous Windows 10/11 avec au moins 8 Go de RAM")
    contents = item.collect()

new_slide("intro_prerequis", title=title, contents=contents)
```

### Logiciels nécessaires (minimum)

```python
title = "Logiciels nécessaires (minimum)"

links = (f"{ml.url_link(url=url, text=name)} - {text}" for name, text, url in [
    (
        "SU2",
        "le logiciel principal de simulation que nous allons utiliser",
        "https://su2code.github.io/"),
    (
        "Gmsh",
        "l'outil capable de générer des mailles pour nos simulations",
        "https://gmsh.info/"),
    (
        "ParaView",
        "le principal outil de visualisation de résults et post-traitement",
        "https://www.paraview.org/"
    ),
    (
        "VS Code",
        "l'éditeur de code conseillé pour éditer les fichiers des modèles",
        "https://code.visualstudio.com/download"
    ),
])

with ml.Itemize(itemsep="3pt") as item:
    item.intro("Le minimum requis en termes de logiciel :", space="6mm")

    for link in links:
        item.add(link)

    items1 = item.collect()

links = (f"Télécharger les {ml.url_link(url=url, text=name)}" for name, url in [
    (
        "tutoriels",
        "https://api.github.com/repos/su2code/Tutorials/zipball/v8.3.0"),
    (
        "cas de test",
        "https://api.github.com/repos/su2code/TestCases/zipball/v8.3.0"
    ),
])

with ml.Itemize(itemsep="3pt") as item:
    item.intro("Vous aurez aussi besoin des tutoriels et cas de test :", space="6mm")
    for link in links:
        item.add(link)

    items2 = item.collect()

with ml.SlideContentWriter() as writer:
    writer.add(items1)
    writer.vspace("6mm")
    writer.add(items2)
    contents = writer.collect()

new_slide("intro_logiciels1", title=title, contents=contents)
```

### Logiciels nécessaires (avancé)

```python
title = "Logiciels nécessaires (avancé)"

links = (f"{ml.url_link(url=url, text=name)} - {text}" for name, text, url in [
    (
        "Python",
         "le langage de \\emph{{scripting}} pour l'automatisation de tâches",
         "https://www.python.org/"
    ),
    (
        "PyVista",
         "la librairie permettant un post-traitement plus avancé des résultats",
         "https://docs.pyvista.org/"
    ),
    (
        "MeshLab",
         "pour une manipulation et correction des maillages génerés",
         "https://www.meshlab.net/"
    ),
    (
        "FreeCAD",
        "pour concevoir des vraies géométries du monde réel",
        "https://www.freecad.org/?lang=fr_FR"
    ),
    (
        "Microsoft MPI",
         "pour le calcul parallèle, si votre ordinateur le permet (admin)",
         "https://learn.microsoft.com/en-us/message-passing-interface/microsoft-mpi"
    ),
])

with ml.Itemize(itemsep="3pt") as item:
    item.intro("Pour les niveaux plus avancés :", space="6mm")

    for link in links:
        item.add(link)

    contents = item.collect()

new_slide("intro_logiciels2", title=title, contents=contents)
```

### Resources supplémentaires

```python
title = "Resources supplémentaires"

links = (ml.url_link(url=url, text=name) for name, url in [
    (
        "SU2 channel (YouTube)",
        "https://www.youtube.com/@su2-opensourcecfd346"
    ),
    (
        "SU2 repository (GitHub)",
        "https://github.com/su2code/SU2"
    ),
    (
        "SU2 forum (CFD online)",
        "https://www.cfd-online.com/Forums/su2/"
    ),
    (
        "This file in special",
        "https://github.com/su2code/SU2/blob/master/config_template.cfg"
    ),
])

with ml.Itemize(itemsep="3pt") as item:
    for link in links:
        item.add(link)

    contents = item.collect()

new_slide("intro_resources", title=title, contents=contents)
```

## Premiers pas

```python
slides.add_section("Premiers pas avec SU2")
```

```python
title = "Le premier tutoriel"

with ml.Itemize(itemsep="3pt") as item:
    item.intro("Un cas de simulation avec SU2 est composé des éléments suivants :")
    item.add("Un fichier \\emph{.cfg} avec les directives de mise-au-point du modèle")
    item.add("Un fichier \\emph{.su2}/\\emph{.cgns} avec le maillage non-structuré du domaine")
    item.add("L'appel au pré-processeur ou directe du solveur \\emph{SU2\\_CFD}")
    item.add("Les étapes de post-process de la solution et analyse des résidus")
    contents = item.collect()

new_slide("sec1_intro", title=title, contents=contents)
```

## Compilation du document

```python
slides.build("_slides.tex")
```
