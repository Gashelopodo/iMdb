//
//  LocalCoreDataService.swift
//  IMdb
//
//  Created by cice on 5/5/17.
//  Copyright © 2017 cice. All rights reserved.
//

import Foundation
import CoreData

class LocalCoreDataService {
    
    let remoteMovieService = RemoteItunesMovieService()
    let stack = CoreDataStack.shared
    
    
    //llamada del buscador
    func searchMovie(_ byTerm : String, remoteHandler : @escaping ([MovieModel]?) -> ()){
        
        remoteMovieService.searchMovies(byTerm) { (result) in
            
            if let movieData = result{
                
                var modelMovie = [MovieModel]()
                
                for c_movie in movieData{
                    
                    let obj = MovieModel(pId: c_movie["id"]!,
                                         pTitle: c_movie["title"],
                                         pOrder: nil,
                                         pSummary: c_movie["summary"]!,
                                         pImage: c_movie["image"]!,
                                         pCategory: c_movie["category"]!,
                                         pDirector: c_movie["director"]!)
                    
                    modelMovie.append(obj)
                    
                    
                }
                
                remoteHandler(modelMovie)
                
            }else{
                
                print("Error mientras se llama a Itunes")
                remoteHandler(nil)
                
            }
            
        }
        
    }
    
    
    
    func topMovie(_ localHandler : @escaping([MovieModel]?) -> (), remoteHandler : @escaping ([MovieModel]?) -> ()){
        
        localHandler(queryTopMovies())
        
        remoteMovieService.getTopMovies { (result) in
            
            if let moviesData = result{
                
                self.markAllmoviesAnunsync()
                var order = 1
                
                for c_movieDiccionario  in moviesData{
                    
                    if let movieDataDes = self.getMovieById(c_movieDiccionario["id"]!, favorito : false){
                        //update
                        self.updateMovie(c_movieDiccionario, movie: movieDataDes, order: order)
                    
                    }else{
                        //insert
                        self.insertMovie(c_movieDiccionario, order: order)
                    }
                    order += 1
                    
                }
                
                //método de remover los no favoritos
                self.removeAllnotFavorite()
                
                remoteHandler(self.queryTopMovies())
                
                
            }else{
                print("Error mientras se llama a la API de Itunes")
                remoteHandler(nil)
            }

        }

    }

    
    func queryTopMovies() -> [MovieModel]? {
        
        let context = stack.persistentContainer.viewContext
        let request : NSFetchRequest<MovieManager> = MovieManager.fetchRequest()
        let sortDescription = NSSortDescriptor(key: "order", ascending: true)
        
        request.sortDescriptors = [sortDescription]
        
        let customPredicate = NSPredicate(format: "favorito = \(false)")
        request.predicate = customPredicate
        
        
        do{
            
            let fetchMovies = try context.fetch(request)
            var movie = [MovieModel]()
            
            for c_movie in fetchMovies{
                movie.append(c_movie.mappedObj())
            }
            
            
            
            return movie
            
        }catch{
            print("Error mientras se obtienen las peliculas desde CoreData")
            return nil
        }
    }
    
    
    func markAllmoviesAnunsync(){
        
        let context = stack.persistentContainer.viewContext
        let request : NSFetchRequest<MovieManager> = MovieManager.fetchRequest()
        
        let customPredicate = NSPredicate(format: "favorito = \(false)")
        request.predicate = customPredicate
        
        
        do{
            let fetchMovies = try context.fetch(request)
            
            for c_manage in fetchMovies{
                c_manage.sync = false
            }
            
            try context.save()
            
        }catch{
            print("Error mientras se actualizan las películas desde CoreData")
        }
    }

    
    func getMovieById(_ id : String, favorito : Bool) -> MovieManager?{
        
        let context = stack.persistentContainer.viewContext
        let request : NSFetchRequest<MovieManager> = MovieManager.fetchRequest()
        
        let customPredicate = NSPredicate(format: "id = '\(id)' AND favorito = \(favorito)")
        request.predicate = customPredicate
        
        do{
            
            let fetchMovies = try context.fetch(request)
            if fetchMovies.count > 0{
                return fetchMovies.last
            }else{
                return nil
            }
            
        }catch{
            print("Error mientras se obtienen las películas desde CoreData")
            return nil
        }
 
    }
    

    func insertMovie(_ movieDiccionario : [String : String], order : Int){
        
        let context = stack.persistentContainer.viewContext
        let movie = MovieManager(context : context)
        
        movie.id = movieDiccionario["id"]
        updateMovie(movieDiccionario, movie : movie, order : order)
        
    }
    
    func updateMovie(_ movieDiccionario : [String : String], movie : MovieManager, order : Int){
        
        let context = stack.persistentContainer.viewContext
        movie.order = Int16(order)
        movie.title = movieDiccionario["title"]
        movie.summary = movieDiccionario["summary"]
        movie.category = movieDiccionario["category"]
        movie.director = movieDiccionario["director"]
        movie.image = movieDiccionario["image"]
        movie.sync = true
        
        do{
            try context.save()
        }catch{
            print("Error mientras se actualiza el CoreData")
        }

    }
    
    func isMovieFavorite(_ movie : MovieModel) -> Bool{
        
        if let _ = getMovieById(movie.id!, favorito: true){
            return true
        }else{
            return false
        }
        
    }
    
    func markUnMarkFavorite(_ movie : MovieModel){
        let context = stack.persistentContainer.viewContext
        if let existe = getMovieById(movie.id!, favorito: true){
            context.delete(existe)
        }else{
            let favorito = MovieManager(context: context)
            favorito.id = movie.id!
            favorito.title = movie.title!
            favorito.summary = movie.summary!
            favorito.category = movie.category!
            favorito.director = movie.director!
            favorito.image = movie.image!
            favorito.favorito = true
            
            do {
                try context.save()
            } catch {
                print("Error mientras marcamos favorito")
            }
            
            
            //actualizar el badge en el tapBar en donde le avisaremos al usuario cuantas peliculas tiene como favoritas
            updateFavoriteBadge()
        }
    }
    
    func getFavoriteMovies() -> [MovieModel]?{
        
        let context = stack.persistentContainer.viewContext
        let request : NSFetchRequest<MovieManager> = MovieManager.fetchRequest()
        
        let customPredicate = NSPredicate(format: "favorito = \(true)")
        request.predicate = customPredicate
        
        do {
            let fetchMovies = try context.fetch(request)
            var movies = [MovieModel]()
            
            for c_movieData in fetchMovies{
                movies.append(c_movieData.mappedObj())
            }
            
            return movies
            
        } catch  {
            print("Error minetras obtenemos favoritos")
            return nil
        }
        
        
    }
    
    func removeFavoriteMovie(_ movie : MovieModel){
        
    }
    
    
    func updateFavoriteBadge(){
        if let totalFavoritos = getFavoriteMovies()?.count{
            let customNotification = Notification(name: Notification.Name("updateFaBadNot"), object: totalFavoritos, userInfo: nil)
            NotificationCenter.default.post(customNotification)
        }
    }
    
    
    func removeAllnotFavorite(){
        
        let context = stack.persistentContainer.viewContext
        let request : NSFetchRequest<MovieManager> = MovieManager.fetchRequest()
        let customPredicate = NSPredicate(format: "favorito = \(false)")
        request.predicate = customPredicate
        
        do {
            let fetchMovies = try context.fetch(request)
            
            for c_movie in fetchMovies{
                if !c_movie.sync{
                    context.delete(c_movie)
                }
            }
            try context.save()
            
        } catch  {
            print("Error minetras se borra el coredata")
            
        }

        
        
    }
    
    
    
    
    
    
    
}
