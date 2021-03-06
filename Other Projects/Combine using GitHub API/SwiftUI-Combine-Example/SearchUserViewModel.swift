import SwiftUI
import Combine

final class SearchUserViewModel: BindableObject {
    var didChange = PassthroughSubject<SearchUserViewModel, Never>()

    private(set) var users = [User]() {
        didSet {
            didChange.send(self)
        }
    }

    private(set) var userImages = [User: UIImage]() {
        didSet {
            didChange.send(self)
        }
    }

    private var cancellable: Cancellable? {
        didSet { oldValue?.cancel() }
    }

    func search(name: String) {
        guard !name.isEmpty else {
            return users = []
        }

        var urlComponents = URLComponents(string: "https://api.github.com/search/users")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: name)
        ]
        var request = URLRequest(url: urlComponents.url!)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let assign = Subscribers.Assign(object: self, keyPath: \.users)
        cancellable = assign

        URLSession.shared.send(request: request)
            .map { $0.data }
            .decode(type: SearchUserResponse.self, decoder: JSONDecoder())
            .map { $0.items }
            .replaceError(with: [])
            .receive(subscriber: assign)
    }

    func getImage(for user: User) {
        guard case .none = userImages[user] else {
            return
        }

        let request = URLRequest(url: user.avatar_url)
        URLSession.shared.send(request: request)
            .map { UIImage(data: $0.data) }
            .replaceError(with: nil)
            .eraseToAnyPublisher()
            .receive(subscriber: Subscribers.Sink<AnyPublisher<UIImage?, Never>> { [weak self] image in
                self?.userImages[user] = image
            })
    }
}
