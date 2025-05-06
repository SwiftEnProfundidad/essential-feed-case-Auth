//
//  Copyright 2019 Essential Developer. All rights reserved.
//

import UIKit
import EssentialFeed
import EssentialFeediOS

final class FeedViewAdapter: ResourceView {
	private weak var controller: ListViewController?
	private let imageLoader: (URL) -> FeedImageDataLoader.Publisher
	private let selection: (FeedImage) -> Void
	// CHANGE: Revert currentFeed to its original purpose now that CellController IDs should be stable via the model.
	private var currentFeed: [FeedImage: CellController]
	
	private typealias ImageDataPresentationAdapter = LoadResourcePresentationAdapter<Data, WeakRefVirtualProxy<FeedImageCellController>>
	private typealias LoadMorePresentationAdapter = LoadResourcePresentationAdapter<Paginated<FeedImage>, FeedViewAdapter>
	
	init(currentFeed: [FeedImage: CellController] = [:], controller: ListViewController, imageLoader: @escaping (URL) -> FeedImageDataLoader.Publisher, selection: @escaping (FeedImage) -> Void) {
		self.currentFeed = currentFeed
		self.controller = controller
		self.imageLoader = imageLoader
		self.selection = selection
	}
	
	func display(_ viewModel: Paginated<FeedImage>) {
		guard let controller = controller else { return }
		
		// currentFeed ahora se usa para intentar reutilizar CellControllers existentes.
		// Esto es importante para mantener el estado de las celdas (ej. si una imagen ya se cargó).
		var feedCellControllers = self.currentFeed
		
		let feed: [CellController] = viewModel.items.map { model in
			// Intenta reutilizar un CellController existente para este FeedImage.
			if let existingCellController = feedCellControllers[model] {
				return existingCellController
			}
			
			let adapter = ImageDataPresentationAdapter(loader: { [imageLoader] in
				imageLoader(model.url)
			})
			
			let view = FeedImageCellController(
				viewModel: FeedImagePresenter.map(model),
				delegate: adapter,
				selection: { [selection] in
					selection(model)
				})
			
			adapter.presenter = LoadResourcePresenter(
				resourceView: WeakRefVirtualProxy(view),
				loadingView: WeakRefVirtualProxy(view),
				errorView: WeakRefVirtualProxy(view),
				mapper: UIImage.tryMake)
			
			// CHANGE: Usar el 'model' (FeedImage) como ID, asumiendo que FeedImage es Hashable
			// y su hash se basa en su 'id: UUID'.
			let cellController = CellController(id: model, view)
			feedCellControllers[model] = cellController // Guardar para posible reutilización
			return cellController
		}
		
		// Actualizar self.currentFeed con el conjunto actual de cell controllers.
		self.currentFeed = feedCellControllers
		
		guard let loadMorePublisher = viewModel.loadMorePublisher else {
			controller.display(feed)
			return
		}
		
		let loadMoreAdapter = LoadMorePresentationAdapter(loader: loadMorePublisher)
		let loadMore = LoadMoreCellController(callback: loadMoreAdapter.loadResource)
		
		loadMoreAdapter.presenter = LoadResourcePresenter(
			resourceView: FeedViewAdapter( // Esta instancia es para el resultado de "cargar más"
				currentFeed: self.currentFeed, // Pasa el feed actual para que pueda intentar fusionar/reutilizar
				controller: controller,
				imageLoader: imageLoader,
				selection: selection
																	 ),
			loadingView: WeakRefVirtualProxy(loadMore),
			errorView: WeakRefVirtualProxy(loadMore))
		
		// El ID para LoadMoreCellController también puede ser un UUID() ya que es único y no se basa en datos.
		let loadMoreSection = [CellController(id: UUID(), loadMore)]
		
		controller.display(feed, loadMoreSection)
	}
}

extension UIImage {
	struct InvalidImageData: Error {}
	
	static func tryMake(data: Data) throws -> UIImage {
		guard let image = UIImage(data: data) else {
			throw InvalidImageData()
		}
		return image
	}
}
